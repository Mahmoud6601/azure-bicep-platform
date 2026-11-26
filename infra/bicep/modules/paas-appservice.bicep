@description('Azure region for App Service resources.')
param location string

@description('Name prefix for App Service Plan and Web App.')
param namePrefix string

@description('App Service Plan SKU (B1, S1, P1v3). Staging slot requires S1 or higher.')
@allowed(['B1', 'S1', 'P1v3'])
param appServiceSku string = 'B1'

@description('Enable zone redundancy (supported on P1v3 in production).')
param zoneRedundant bool = false

@description('Subnet ID for App Service VNet Integration.')
param appServiceSubnetId string

@description('ACR login server hosting the immutable verification container.')
param acrLoginServer string

@description('ACR resource ID for AcrPull RBAC role assignment.')
param acrId string

@description('Initial immutable container image tag.')
param imageTag string = 'local-dev'

@description('Log Analytics Workspace ID for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Action Group ID for HTTP 5xx metric alerts.')
param actionGroupId string

@description('Common resource tags.')
param tags object

var supportsSlots = appServiceSku != 'B1'
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${namePrefix}-asp'
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: appServiceSku
  }
  properties: {
    reserved: true
    zoneRedundant: zoneRedundant && appServiceSku == 'P1v3'
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: '${namePrefix}-web'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    virtualNetworkSubnetId: appServiceSubnetId
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/azure-web-payload:${imageTag}'
      acrUseManagedIdentityCreds: true
      alwaysOn: appServiceSku != 'B1'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      healthCheckPath: '/healthz'
      appSettings: [
        { name: 'WEBSITES_PORT', value: '8080' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
      ]
    }
  }
}

resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = if (supportsSlots) {
  parent: webApp
  name: 'staging'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    virtualNetworkSubnetId: appServiceSubnetId
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/azure-web-payload:${imageTag}'
      acrUseManagedIdentityCreds: true
      alwaysOn: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      healthCheckPath: '/healthz'
      appSettings: [
        { name: 'WEBSITES_PORT', value: '8080' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
      ]
    }
  }
}

resource acrExisting 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: last(split(acrId, '/'))
}

resource webAppAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrExisting.id, webApp.id, acrPullRoleId)
  scope: acrExisting
  properties: {
    principalId: webApp.identity.principalId
    roleDefinitionId: acrPullRoleId
    principalType: 'ServicePrincipal'
  }
}

resource appDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'appservice-diagnostics'
  scope: webApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'AppServiceHTTPLogs', enabled: true }
      { category: 'AppServiceConsoleLogs', enabled: true }
      { category: 'AppServiceAppLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

resource http5xxAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${namePrefix}-paas-http5xx-alert'
  location: 'global'
  tags: tags
  properties: {
    description: 'Triggers when App Service emits HTTP 5xx errors.'
    severity: 2
    enabled: true
    scopes: [webApp.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xx'
          metricName: 'Http5xx'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      { actionGroupId: actionGroupId }
    ]
  }
}

output webAppName string = webApp.name
output defaultHostName string = webApp.properties.defaultHostName
output stagingHostName string = supportsSlots ? stagingSlot.properties.defaultHostName : ''
output hasStagingSlot bool = supportsSlots
