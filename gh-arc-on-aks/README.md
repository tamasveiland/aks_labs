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
- **GitHub PAT** (Personal Access Token) with the following scopes:
  - For **organization** runners: `admin:org`
  - For **repository** runners: `repo`

### Creating a GitHub PAT

1. Go to [github.com/settings/tokens](https://github.com/settings/tokens)
2. Click **Generate new token (classic)**
3. Select the `admin:org` scope (for org-level runners) or `repo` scope (for repo-level runners)
4. Copy the generated token — you'll need it during setup

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

# Set the GitHub PAT
azd env set GITHUB_PAT "ghp_your_token_here"

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
- Verify the PAT has correct scopes
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
