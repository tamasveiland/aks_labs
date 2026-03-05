## GitHub Actions Runner Controller - Kubernetes Manifests

The ARC controller and runner scale sets are installed via Helm in the post-provisioning
scripts. The YAML files in this directory serve as reference templates.

### Files

| File | Purpose |
|------|---------|
| `arc-runner-scaleset.yaml` | Example AutoScalingRunnerSet custom resource |

> **Note**: ARC v2 (gha-runner-scale-set) uses Helm-based installation.
> The controller and listener are installed via the `gha-runner-scale-set-controller`
> chart, and runner scale sets via the `gha-runner-scale-set` chart.
> The YAML here is provided for reference only.
