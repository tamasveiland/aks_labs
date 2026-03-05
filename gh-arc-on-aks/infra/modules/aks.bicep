@description('Name of the AKS cluster')
param name string

@description('Azure region for the AKS cluster')
param location string

@description('Kubernetes version')
param kubernetesVersion string

@description('VM size for the system node pool')
param systemNodeVmSize string

@description('Number of nodes in the system node pool')
param systemNodeCount int

@description('VM size for the runner node pool')
param runnerNodeVmSize string

@description('Minimum node count for the runner node pool')
param runnerNodeMinCount int

@description('Maximum node count for the runner node pool')
param runnerNodeMaxCount int

@description('Principal ID of the current user for AKS data plane admin access')
param currentUserPrincipalId string = ''

@description('Tags to apply to all resources')
param tags object = {}

resource aks 'Microsoft.ContainerService/managedClusters@2024-06-02-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: name
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    agentPoolProfiles: [
      {
        name: 'system'
        count: systemNodeCount
        vmSize: systemNodeVmSize
        mode: 'System'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false
      }
      {
        name: 'runners'
        minCount: runnerNodeMinCount
        maxCount: runnerNodeMaxCount
        count: runnerNodeMinCount > 0 ? runnerNodeMinCount : 1
        vmSize: runnerNodeVmSize
        mode: 'User'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: true
        nodeTaints: [
          'github-runner=true:NoSchedule'
        ]
        nodeLabels: {
          'github-runner': 'true'
        }
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'cilium'
      networkDataplane: 'cilium'
      loadBalancerSku: 'standard'
    }
  }
}

// Azure Kubernetes Service RBAC Cluster Admin role assignment for the current user
resource aksRbacClusterAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(currentUserPrincipalId)) {
  name: guid(aks.id, currentUserPrincipalId, 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
    principalId: currentUserPrincipalId
    principalType: 'User'
  }
}

output clusterName string = aks.name
output clusterFqdn string = aks.properties.fqdn
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
