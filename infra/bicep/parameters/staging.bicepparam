using '../main.bicep'

param environment = 'staging'
param deploymentTrack = 'paas'
param projectName = 'azweb'
param appServiceSku = 'S1'
param enableBastion = false
param enablePurgeProtection = true
param logRetentionDays = 30
param imageTag = 'local-dev'
