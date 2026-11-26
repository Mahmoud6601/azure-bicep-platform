@description('Azure region for Storage Account and Container Registry.')
param location string

@description('Globally unique lowercase Storage Account name (3-24 alphanumeric).')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Globally unique ACR name (5-50 alphanumeric).')
@minLength(5)
@maxLength(50)
param acrName string

@description('Deploy Azure Container Registry (required for PaaS container track).')
param enableAcr bool = true

@description('Common resource tags.')
param tags object

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: true
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource releasesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'iis-releases'
  properties: {
    publicAccess: 'None'
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'appservice-backups'
  properties: {
    publicAccess: 'None'
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = if (enableAcr) {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output storageAccountId string = storage.id
output storageAccountName string = storage.name
output acrId string = enableAcr ? acr.id : ''
output acrLoginServer string = enableAcr ? acr.properties.loginServer : ''
