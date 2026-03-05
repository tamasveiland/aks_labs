targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment (used to generate a unique resource group name)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the AKS cluster')
param aksClusterName string = ''

@description('Kubernetes version for the AKS cluster')
param kubernetesVersion string = '1.34.2'

@description('VM size for the AKS system node pool')
param systemNodeVmSize string = 'Standard_DS2_v2'

@description('Number of nodes in the system node pool')
param systemNodeCount int = 2

@description('VM size for the runner node pool')
param runnerNodeVmSize string = 'Standard_DS2_v2'

@description('Minimum number of nodes in the runner node pool (autoscaler)')
param runnerNodeMinCount int = 0

@description('Maximum number of nodes in the runner node pool (autoscaler)')
param runnerNodeMaxCount int = 5

@description('GitHub organization or repository URL for the runner (e.g. https://github.com/myorg)')
param githubConfigUrl string = ''

@description('Principal ID of the current user for AKS data plane admin access')
param currentUserPrincipalId string = ''

@description('Tags to apply to all resources')
param tags object = {}

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var clusterName = !empty(aksClusterName) ? aksClusterName : '${abbrs.containerServiceManagedClusters}${resourceToken}'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: union(tags, { 'azd-env-name': environmentName })
}

// AKS Cluster
module aks 'modules/aks.bicep' = {
  name: 'aks'
  scope: rg
  params: {
    name: clusterName
    location: location
    kubernetesVersion: kubernetesVersion
    systemNodeVmSize: systemNodeVmSize
    systemNodeCount: systemNodeCount
    runnerNodeVmSize: runnerNodeVmSize
    runnerNodeMinCount: runnerNodeMinCount
    runnerNodeMaxCount: runnerNodeMaxCount
    currentUserPrincipalId: currentUserPrincipalId
    tags: union(tags, { 'azd-env-name': environmentName })
  }
}

// Outputs for azd and post-provisioning scripts
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_AKS_CLUSTER_NAME string = aks.outputs.clusterName
output AZURE_AKS_OIDC_ISSUER_URL string = aks.outputs.oidcIssuerUrl
output GITHUB_CONFIG_URL string = githubConfigUrl
