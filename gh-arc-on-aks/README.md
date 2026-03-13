# GitHub Actions Runner Controller (ARC) on AKS

This lab deploys an AKS cluster configured to host **GitHub Actions Runner Controller (ARC)** — enabling self-hosted GitHub Actions runners that autoscale on Kubernetes.

## Overview

[Actions Runner Controller (ARC)](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller) is a Kubernetes operator that orchestrates and scales self-hosted runners for GitHub Actions. This lab uses **ARC v2** (the `gha-runner-scale-set` approach) running on an AKS cluster, deployed and managed with the Azure Developer CLI (`azd`).

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Azure Resource Group                   │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │                  AKS Cluster                       │  │
│  │                                                    │  │
│  │  ┌──────────────┐    ┌───────────────────────────┐│  │
│  │  │ System Pool   │    │ Runner Pool (autoscale)   ││  │
│  │  │               │    │                           ││  │
│  │  │ arc-systems   │    │ arc-runners               ││  │
│  │  │ namespace:    │    │ namespace:                ││  │
│  │  │ - controller  │    │ - runner pods             ││  │
│  │  │ - listener    │    │   (scale 0 → N)           ││  │
│  │  └──────────────┘    └───────────────────────────┘│  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
└──────────────────────────────────────────────────────────┘
          │                           ▲
          │  Watches for workflow     │  Reports status &
          │  job events               │  registers runners
          ▼                           │
┌──────────────────────────────────────────────────────────┐
│                     GitHub                                │
│  Organization / Repository                                │
│  - Workflow jobs with `runs-on: arc-runner-set`          │
└──────────────────────────────────────────────────────────┘
```

### What gets deployed

| Resource | Purpose |
|----------|---------|
| **AKS Cluster** | Hosts the ARC controller and runner pods |
| **System Node Pool** | Runs ARC controller, listener, and Kubernetes system workloads |
| **Runner Node Pool** | Dedicated autoscaling pool (0–5 nodes) with taints for runner pods |
| **ARC Controller** (Helm) | Kubernetes operator managing runner lifecycle |
| **Runner Scale Set** (Helm) | Autoscaling set of GitHub Actions runner pods |

## Prerequisites

- **Azure subscription** with permissions to create AKS clusters
- **Azure CLI** (`az`) installed and authenticated
- **Azure Developer CLI** (`azd`) >= 1.x installed
- **kubectl** installed
- **Helm** >= 3.x installed
- **GitHub App** installed on your organization (or repository) with the **Self-hosted runners** (Read & Write) organization permission. See [Creating a GitHub App](#creating-a-github-app) below.

### Creating a GitHub App

#### 1. Create the App

1. Go to your **org Settings → Developer settings → GitHub Apps → New GitHub App**
2. Fill in:
   - **App name**: e.g., `arc-runner-controller`
   - **Homepage URL**: any valid URL (e.g., your org's GitHub URL)
3. Under **Webhook**, **uncheck Active** (ARC doesn't need webhooks)
4. Under **Permissions**, set:

   **Organization permissions:**
   | Permission | Access |
   |------------|--------|
   | **Self-hosted runners** | **Read & Write** |

   **Repository permissions:**
   | Permission | Access |
   |------------|--------|
   | **Actions** | **Read-only** |
   | **Administration** | **Read & Write** |
   | **Metadata** | **Read-only** (automatically selected) |

5. Under **Where can this GitHub App be installed?**, select **Only on this account**
6. Click **Create GitHub App**

#### 2. Get the credentials

1. On the app's **General** page, note the **App ID**
2. Scroll to **Private keys** → click **Generate a private key** → save the downloaded `.pem` file
3. In the sidebar, click **Install App** → install it on your organization (select **All repositories** or specific ones)
4. After installing, the URL will be `https://github.com/organizations/YOUR_ORG/settings/installations/XXXXX` — the number at the end is your **Installation ID**

You will need three values for the setup:

| Value | Where to find it |
|-------|-------------------|
| **App ID** | App's General settings page |
| **Installation ID** | URL after installing the app on your org |
| **Private key** (`.pem` file) | Downloaded when generating a private key |

#### Enterprise-level GitHub App (optional)

If you need runners across **multiple organizations** in a GitHub Enterprise, you can create the app at the enterprise level instead:

1. Go to **Enterprise settings → Developer settings → GitHub Apps → New GitHub App**
   (`https://github.com/enterprises/YOUR_ENTERPRISE/settings/apps/new`)
2. Use the same permissions and webhook configuration as above
3. After creating, **install the app** on each organization that needs runners

Key differences from org-level apps:

| Aspect | Organization App | Enterprise App |
|--------|-----------------|----------------|
| **Scope** | Single org | All orgs in the enterprise |
| **Installation** | Installed on the creating org | Must be installed on each target org |
| **Visibility** | Only the creating org | All orgs in the enterprise |

> **Note:** Even with an enterprise-level app, the ARC `GITHUB_CONFIG_URL` must still point to a **specific organization** (or repo) — not the enterprise URL. Use the **Installation ID** corresponding to the org in your `GITHUB_CONFIG_URL`.

#### Installing across multiple organizations

There is **no API to programmatically install** a GitHub App — installation always requires user consent through the GitHub UI. However, you can automate parts of the workflow:

| Task | Programmatic? | How |
|------|--------------|-----|
| **Create the app** | Yes | [REST API](https://docs.github.com/en/rest/apps/apps#create-a-github-app) or [manifest flow](https://docs.github.com/en/apps/creating-github-apps/setting-up-a-github-app/creating-a-github-app-from-a-manifest) |
| **Install on an org** | **No** — requires UI consent | Share the link: `https://github.com/apps/YOUR_APP_NAME/installations/new` |
| **List installations** | Yes | `GET /app/installations` (authenticated as the app) |
| **Get Installation ID for an org** | Yes | `GET /orgs/{org}/installation` (authenticated as the app) |

**Multi-org rollout steps:**

1. Create the app at the **enterprise level** (or make an org-level app **public** under the app's Advanced settings)
2. Share the install link with org admins: `https://github.com/apps/YOUR_APP_NAME/installations/new`
3. Each org admin clicks through and selects which repos to grant access
4. Programmatically discover each org's Installation ID:
   ```bash
   # Generate a JWT from your App ID + private key, then:
   curl -H "Authorization: Bearer $JWT" \
        -H "Accept: application/vnd.github+json" \
        https://api.github.com/app/installations
   ```
5. For each org/AKS cluster, set the corresponding Installation ID via `azd env set GITHUB_APP_INSTALLATION_ID`

## Quick Start

### 1. Initialize the azd environment

```bash
cd gh-arc-on-aks
azd init
```

When prompted, select **Use code in the current directory**.

### 2. Configure environment variables

```bash
# Set the GitHub organization or repository URL
azd env set GITHUB_CONFIG_URL "https://github.com/YOUR_ORG"
# or for a specific repo:
# azd env set GITHUB_CONFIG_URL "https://github.com/YOUR_ORG/YOUR_REPO"

# Set the GitHub App credentials
azd env set GITHUB_APP_ID "12345"
azd env set GITHUB_APP_INSTALLATION_ID "67890"
azd env set GITHUB_APP_PRIVATE_KEY_PATH "/path/to/private-key.pem"

# Grant your user AKS RBAC Cluster Admin on the data plane
azd env set AZURE_PRINCIPAL_ID (az ad signed-in-user show --query id -o tsv)
```

### 3. Provision and deploy

```bash
azd up
```

This will:
1. Prompt you for an Azure subscription and location
2. Create the AKS cluster with system and runner node pools
3. Run the post-provisioning script that installs ARC via Helm

### 4. Verify the installation

After provisioning completes, check the runner pods:

```bash
# Check ARC controller
kubectl get pods -n arc-systems

# Check runner scale set
kubectl get pods -n arc-runners

# View the AutoscalingRunnerSet CR
kubectl get autoscalingrunnersets -n arc-runners
```

## Using the Runners

Once deployed, use the self-hosted runners in your GitHub Actions workflows:

```yaml
name: CI
on: [push]

jobs:
  build:
    runs-on: arc-runner-set   # <-- matches the Helm release name
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on ARC self-hosted runner!"
```

The ARC controller will automatically:
- Detect queued workflow jobs targeting `arc-runner-set`
- Spin up runner pods on the dedicated runner node pool
- Scale the node pool via the Kubernetes cluster autoscaler
- Tear down runner pods after job completion

### Node Scheduling: Taints, Labels & NodeSelectors

The AKS cluster uses **taints**, **labels**, and **nodeSelectors** to ensure runner pods are isolated on the dedicated runner node pool.

**In the Bicep template** (`infra/modules/aks.bicep`), the runner node pool is configured with:

```bicep
nodeTaints: [
  'github-runner=true:NoSchedule'
]
nodeLabels: {
  'github-runner': 'true'
}
```

**In the Helm install** (`scripts/post-provision.ps1`), the runner scale set is configured with matching tolerations and a nodeSelector:

```
--set "template.spec.tolerations[0].key=github-runner"
--set "template.spec.tolerations[0].operator=Equal"
--set-string "template.spec.tolerations[0].value=true"
--set "template.spec.tolerations[0].effect=NoSchedule"
--set-string "template.spec.nodeSelector.github-runner=true"
```

How these work together:

| Mechanism | Where | Purpose |
|-----------|-------|---------|
| **Taint** (`NoSchedule`) | Runner node pool | Repels all pods that don't have a matching toleration, keeping non-runner workloads off runner nodes |
| **Toleration** | Runner pods (Helm) | Allows runner pods to schedule onto the tainted runner nodes |
| **Label** | Runner node pool | Tags runner nodes with `github-runner=true` |
| **NodeSelector** | Runner pods (Helm) | Ensures runner pods are *only* placed on nodes with the `github-runner=true` label |

> **Note:** The `--set-string` flag is used for the toleration value and nodeSelector because Helm's `--set` would interpret `true` as a YAML boolean, but Kubernetes expects these as strings.

## Configuration

### Customizing the AKS cluster

Edit `infra/main.bicep` parameters or override at provision time:

```bash
azd env set AZURE_AKS_CLUSTER_NAME "my-arc-cluster"
```

Key parameters in `infra/main.bicep`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `kubernetesVersion` | `1.30` | AKS Kubernetes version |
| `systemNodeVmSize` | `Standard_DS2_v2` | VM size for system nodes |
| `systemNodeCount` | `2` | Number of system nodes |
| `runnerNodeVmSize` | `Standard_DS2_v2` | VM size for runner nodes |
| `runnerNodeMinCount` | `0` | Min runner nodes (autoscaler) |
| `runnerNodeMaxCount` | `5` | Max runner nodes (autoscaler) |

### Customizing the runner scale set

Modify values in the post-provisioning script or pass Helm values:

```bash
helm upgrade --install arc-runner-set \
    --namespace arc-runners \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
    --set githubConfigUrl="https://github.com/YOUR_ORG" \
    --set maxRunners=10 \
    --set minRunners=1 \
    -f custom-values.yaml
```

## Cleanup

Remove all Azure resources:

```bash
azd down --purge
```

## Troubleshooting

### Runner pods stuck in Pending

Check if the runner node pool is scaling:
```bash
kubectl describe nodes -l github-runner=true
kubectl get events -n arc-runners --sort-by='.lastTimestamp'
```

### ARC controller not starting

```bash
kubectl logs -n arc-systems -l app.kubernetes.io/name=gha-runner-scale-set-controller
```

### Runners not appearing in GitHub

- Verify `GITHUB_CONFIG_URL` is correct
- Verify the GitHub App has the correct permissions and is installed on the org/repo
- Check the listener logs:
  ```bash
  kubectl logs -n arc-systems -l actions.github.com/scale-set-name=arc-runner-set
  ```

### Re-run post-provisioning

If you need to reconfigure after changing environment variables:
```bash
azd hooks run postprovision
```

## References

- [ARC Documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller)
- [ARC Quickstart](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/quickstart-for-actions-runner-controller)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
