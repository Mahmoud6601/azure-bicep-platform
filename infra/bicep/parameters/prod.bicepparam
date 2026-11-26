using '../main.bicep'

param environment = 'prod'
param deploymentTrack = 'paas'
param projectName = 'azweb'
param appServiceSku = 'P1v3'
param enableBastion = true
param enablePurgeProtection = true
param logRetentionDays = 90
param imageTag = 'local-dev'
