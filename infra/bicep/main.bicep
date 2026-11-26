targetScope = 'resourceGroup'

@description('Deployment environment (dev, staging, prod).')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Deployment track to provision: paas, iaas, or both.')
@allowed(['paas', 'iaas', 'both'])
param deploymentTrack string = 'paas'

@description('Azure region (defaults to resource group location).')
param location string = resourceGroup().location

@description('Short project prefix.')
param projectName string = 'azweb'

@description('App Service SKU for Track A PaaS (B1, S1, P1v3).')
@allowed(['B1', 'S1', 'P1v3'])
param appServiceSku string = 'B1'

@description('Enable Azure Bastion for zero-public-RDP IaaS access.')
param enableBastion bool = false

@description('Enable Key Vault purge protection.')
param enablePurgeProtection bool = false

@description('Log Analytics retention in days.')
param logRetentionDays int = 30

@description('Initial immutable container image tag for Track A PaaS.')
param imageTag string = 'local-dev'

@description('Windows VM admin password (required only when deploymentTrack is iaas or both).')
@secure()
param iaasAdminPassword string = ''

var namePrefix = '${projectName}-${environment}'
var uniqueSuffix = take(uniqueString(resourceGroup().id, namePrefix), 6)
var commonTags = {
  Project: projectName
  Environment: environment
  ManagedBy: 'bicep'
  Track: deploymentTrack
}

var deployPaas = deploymentTrack == 'paas' || deploymentTrack == 'both'
var deployIaas = deploymentTrack == 'iaas' || deploymentTrack == 'both'

module network 'modules/network.bicep' = {
  name: '${namePrefix}-network'
  params: {
    location: location
    namePrefix: namePrefix
    vnetCidr: '10.40.0.0/16'
    appServiceSubnetCidr: '10.40.1.0/24'
    privateEndpointSubnetCidr: '10.40.2.0/24'
    iaasWebSubnetCidr: '10.40.3.0/24'
    bastionSubnetCidr: '10.40.4.0/26'
    enableBastion: enableBastion
    tags: commonTags
  }
}

module observability 'modules/observability.bicep' = {
  name: '${namePrefix}-observability'
  params: {
    location: location
    namePrefix: namePrefix
    retentionInDays: logRetentionDays
    tags: commonTags
  }
}

module keyVault 'modules/security-keyvault.bicep' = {
  name: '${namePrefix}-keyvault'
  params: {
    location: location
    keyVaultName: take('kv-${namePrefix}-${uniqueSuffix}', 24)
    logAnalyticsWorkspaceId: observability.outputs.logAnalyticsWorkspaceId
    enablePurgeProtection: enablePurgeProtection
    tags: commonTags
  }
}

module storageAcr 'modules/storage-acr.bicep' = {
  name: '${namePrefix}-storage-acr'
  params: {
    location: location
    storageAccountName: toLower(take('st${projectName}${environment}${uniqueSuffix}', 24))
    acrName: toLower(take('acr${projectName}${environment}${uniqueSuffix}', 50))
    enableAcr: deployPaas
    tags: commonTags
  }
}

module paas 'modules/paas-appservice.bicep' = if (deployPaas) {
  name: '${namePrefix}-paas'
  params: {
    location: location
    namePrefix: '${namePrefix}-${uniqueSuffix}'
    appServiceSku: appServiceSku
    zoneRedundant: environment == 'prod'
    appServiceSubnetId: network.outputs.appServiceSubnetId
    acrLoginServer: storageAcr.outputs.acrLoginServer
    acrId: storageAcr.outputs.acrId
    imageTag: imageTag
    logAnalyticsWorkspaceId: observability.outputs.logAnalyticsWorkspaceId
    appInsightsConnectionString: observability.outputs.appInsightsConnectionString
    actionGroupId: observability.outputs.actionGroupId
    tags: commonTags
  }
}

module iaas 'modules/iaas-iis-vm.bicep' = if (deployIaas) {
  name: '${namePrefix}-iaas'
  params: {
    location: location
    namePrefix: namePrefix
    iaasWebSubnetId: network.outputs.iaasWebSubnetId
    adminPassword: iaasAdminPassword
    storageAccountId: storageAcr.outputs.storageAccountId
    tags: commonTags
  }
}

output storageAccountName string = storageAcr.outputs.storageAccountName
output acrLoginServer string = storageAcr.outputs.acrLoginServer
output paasWebAppName string = deployPaas ? paas.outputs.webAppName : ''
output paasDefaultHostName string = deployPaas ? paas.outputs.defaultHostName : ''
output paasStagingHostName string = deployPaas ? paas.outputs.stagingHostName : ''
output iaasVmName string = deployIaas ? iaas.outputs.vmName : ''
output iaasLoadBalancerIp string = deployIaas ? iaas.outputs.loadBalancerPublicIp : ''
