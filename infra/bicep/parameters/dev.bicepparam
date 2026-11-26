using '../main.bicep'

param environment = 'dev'
param deploymentTrack = 'paas'
param projectName = 'azweb'
param appServiceSku = 'B1'
param enableBastion = false
param enablePurgeProtection = false
param logRetentionDays = 30
param imageTag = 'local-dev'
