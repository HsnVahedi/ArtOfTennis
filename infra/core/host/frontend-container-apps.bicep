metadata description = 'Creates an Azure Container Registry and an Azure Container Apps environment.'
param name string
param location string = resourceGroup().location
param tags object = {}

param containerAppsEnvironmentName string
param containerRegistryName string
param containerRegistryResourceGroupName string = ''
// param containerRegistryAdminUserEnabled bool = false
param logAnalyticsWorkspaceResourceId string
// param applicationInsightsName string = '' // Not used here, was used for DAPR
param virtualNetworkSubnetId string = ''

@description('Optional user assigned identity IDs to assign to the resource')
param userAssignedIdentityResourceIds array = []


resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' existing = {
  name: containerRegistryName
}

module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.5.2' = {
  name: '${name}-frontend-container-apps-environment'
  params: {
    // Required parameters
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId

    managedIdentities: empty(userAssignedIdentityResourceIds) ? {
      systemAssigned: true
    } : {
      userAssignedResourceIds: userAssignedIdentityResourceIds
    }

    name: containerAppsEnvironmentName
    // Non-required parameters
    infrastructureResourceGroupName: containerRegistryResourceGroupName
    infrastructureSubnetId: virtualNetworkSubnetId
    // internal: false
    location: location
    tags: tags
  }
}

// module containerRegistry 'br/public:avm/res/container-registry/registry:0.3.1' = {
//   name: '${name}-container-registry'
//   scope: !empty(containerRegistryResourceGroupName) ? resourceGroup(containerRegistryResourceGroupName) : resourceGroup()
//   params: {
//     name: containerRegistryName
//     location: location
//     acrAdminUserEnabled: containerRegistryAdminUserEnabled
//     tags: tags
//   }
// }

output defaultDomain string = containerAppsEnvironment.outputs.defaultDomain
output environmentName string = containerAppsEnvironment.outputs.name
output environmentId string = containerAppsEnvironment.outputs.resourceId

// output registryLoginServer string = containerRegistry.outputs.loginServer
output registryName string = containerRegistry.name
