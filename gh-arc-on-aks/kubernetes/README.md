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

> **Note**: The `gha-runner-scale-set` chart is a wrapper around the `gha-runner` chart that adds autoscaling capabilities. The runner pods themselves are defined in the `gha-runner` chart templates:
https://github.com/actions/actions-runner-controller/blob/master/charts/gha-runner-scale-set/templates/autoscalingrunnerset.yaml

### Investigation & Debugging
To investigate runner pods and their scheduling:
1. List runner pods:
   ```bash
   kubectl get pods -n arc-runners
   ```
2. Describe a runner pod to see node scheduling details:
   ```bash
   kubectl describe pod <runner-pod-name> -n arc-runners
   ```
3. Check events in the `arc-runners` namespace for any scheduling issues:
   ```bash
   kubectl get events -n arc-runners --sort-by='.lastTimestamp'
   ```

You can also check the status of the runner scale set custom resource:
```bash
kubectl get autoscalingrunnersets -n arc-runners
kubectl describe autoscalingrunnerset arc-runner-set -n arc-runners
```

You can also check the logs of the ARC controller and listener for any errors or warnings:
```bash
kubectl logs -n arc-systems -l app.kubernetes.io/name=gha-runner-scale-set-controller
kubectl logs -n arc-systems -l actions.github.com/scale-set-name=arc-runner-set
``` 

You can view the custom resource definitions (CRDs):
```bash
kubectl get crds | Select-String "actions.github.com"
```

You can view the custom resource definitions (CRDs) for the runner scale set to understand the schema and available fields:
```bash
kubectl get crd autoscalingrunnersets.actions.github.com -o yaml
```

You can view the custom resource:
```bash
kubectl get autoscalingrunnersets -n arc-runners arc-runner-set -o yaml
```
