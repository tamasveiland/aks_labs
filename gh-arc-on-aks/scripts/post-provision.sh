#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Post-provisioning script for GitHub Actions Runner Controller (ARC) on AKS.
# Installs the ARC Helm charts and configures a runner scale set.
#
# This script runs automatically after `azd provision`. It:
# 1. Retrieves AKS credentials
# 2. Installs the ARC controller via Helm
# 3. Installs a runner scale set connected to your GitHub org/repo
#
# Requires: az CLI, kubectl, helm
# Environment variables are set automatically by azd from Bicep outputs.
# ---------------------------------------------------------------------------

set -euo pipefail

# ---------------------------------------------------------------------------
# Load azd environment variables into the current session
# ---------------------------------------------------------------------------
echo "=== Loading azd environment variables ==="
while IFS='=' read -r key value; do
    value="${value%\"}"
    value="${value#\"}"
    export "$key=$value"
done < <(azd env get-values)

# ---------------------------------------------------------------------------
# Read azd outputs (now available as environment variables)
# ---------------------------------------------------------------------------
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:?'AZURE_RESOURCE_GROUP is not set. This should be set by azd.'}"
CLUSTER_NAME="${AZURE_AKS_CLUSTER_NAME:?'AZURE_AKS_CLUSTER_NAME is not set. This should be set by azd.'}"
GITHUB_CONFIG_URL="${GITHUB_CONFIG_URL:-}"
GITHUB_PAT="${GITHUB_PAT:-}"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [[ -z "$GITHUB_CONFIG_URL" ]]; then
    echo "WARNING: GITHUB_CONFIG_URL is not set. Skipping ARC runner scale set installation."
    echo "Set GITHUB_CONFIG_URL to your GitHub org or repo URL, then run: azd hooks run postprovision"
    exit 0
fi

if [[ -z "$GITHUB_PAT" ]]; then
    echo "WARNING: GITHUB_PAT is not set. Skipping ARC runner scale set installation."
    echo "Create a GitHub PAT with the required scopes and set it:"
    echo "  azd env set GITHUB_PAT <your-pat>"
    echo "Then re-run: azd hooks run postprovision"
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Get AKS credentials
# ---------------------------------------------------------------------------
echo ""
echo "=== Getting AKS credentials ==="
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing

# ---------------------------------------------------------------------------
# 2. Add the ARC Helm repository
# ---------------------------------------------------------------------------
echo ""
echo "=== Adding ARC Helm repository ==="
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller 2>/dev/null || true
helm repo update

# ---------------------------------------------------------------------------
# 3. Install the ARC controller (gha-runner-scale-set-controller)
# ---------------------------------------------------------------------------
ARC_SYSTEM_NAMESPACE="arc-systems"
ARC_RUNNERS_NAMESPACE="arc-runners"

echo ""
echo "=== Installing ARC controller in namespace '$ARC_SYSTEM_NAMESPACE' ==="

# Create namespaces if they don't exist
kubectl create namespace "$ARC_SYSTEM_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$ARC_RUNNERS_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install arc \
    --namespace "$ARC_SYSTEM_NAMESPACE" \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
    --wait

echo "ARC controller installed successfully."

# ---------------------------------------------------------------------------
# 4. Install a runner scale set
# ---------------------------------------------------------------------------
echo ""
echo "=== Installing ARC runner scale set ==="

helm upgrade --install arc-runner-set \
    --namespace "$ARC_RUNNERS_NAMESPACE" \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
    --set githubConfigUrl="$GITHUB_CONFIG_URL" \
    --set githubConfigSecret.github_token="$GITHUB_PAT" \
    --set "template.spec.tolerations[0].key=github-runner" \
    --set "template.spec.tolerations[0].operator=Equal" \
    --set "template.spec.tolerations[0].value=true" \
    --set "template.spec.tolerations[0].effect=NoSchedule" \
    --set "template.spec.nodeSelector.github-runner=true" \
    --set maxRunners=5 \
    --set minRunners=0 \
    --wait

echo "ARC runner scale set installed successfully."

# ---------------------------------------------------------------------------
# 5. Verify installation
# ---------------------------------------------------------------------------
echo ""
echo "=== Verifying ARC installation ==="
echo ""
echo "Pods in $ARC_SYSTEM_NAMESPACE namespace:"
kubectl get pods -n "$ARC_SYSTEM_NAMESPACE"

echo ""
echo "Pods in $ARC_RUNNERS_NAMESPACE namespace:"
kubectl get pods -n "$ARC_RUNNERS_NAMESPACE"

echo ""
echo "=== Post-provisioning complete ==="
echo "Your self-hosted runners will appear in GitHub under:"
echo "  $GITHUB_CONFIG_URL/settings/actions/runners"
echo ""
echo "To use these runners in a workflow, set:"
echo "  runs-on: arc-runner-set"
echo ""
