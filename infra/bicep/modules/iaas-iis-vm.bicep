@description('Azure region for IaaS IIS VM and Load Balancer.')
param location string

@description('Name prefix for IaaS resources.')
param namePrefix string

@description('Private subnet ID for the Windows Server IIS VM (zero public IP).')
param iaasWebSubnetId string

@description('Windows VM size.')
param vmSize string = 'Standard_B2ms'

@description('Local administrator username for the Windows VM.')
param adminUsername string = 'iisadmin'

@description('Local administrator password (injected at deployment time from Key Vault / CI secret).')
@secure()
param adminPassword string

@description('Storage Account ID hosting private IIS release ZIPs for Managed Identity RBAC.')
param storageAccountId string

@description('Common resource tags.')
param tags object

var storageBlobReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')

resource lbPip 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${namePrefix}-iaas-lb-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource lb 'Microsoft.Network/loadBalancers@2024-03-01' = {
  name: '${namePrefix}-iaas-lb'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'lb-frontend'
        properties: {
          publicIPAddress: {
            id: lbPip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'iis-backend-pool'
      }
    ]
    probes: [
      {
        name: 'healthz-probe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/health.json'
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'https-443'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${namePrefix}-iaas-lb', 'lb-frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${namePrefix}-iaas-lb', 'iis-backend-pool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${namePrefix}-iaas-lb', 'healthz-probe')
          }
          protocol: 'Tcp'
          frontendPort: 443
          backendPort: 443
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${namePrefix}-iis-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: iaasWebSubnetId
          }
          loadBalancerBackendAddressPools: [
            {
              id: lb.properties.backendAddressPools[0].id
            }
          ]
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${namePrefix}-iis-vm'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    osProfile: {
      computerName: take(replace('${namePrefix}iis', '-', ''), 15)
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource storageExisting 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: last(split(storageAccountId, '/'))
}

resource vmBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageExisting.id, vm.id, storageBlobReaderRoleId)
  scope: storageExisting
  properties: {
    principalId: vm.identity.principalId
    roleDefinitionId: storageBlobReaderRoleId
    principalType: 'ServicePrincipal'
  }
}

resource recoveryVault 'Microsoft.RecoveryServices/vaults@2024-04-01' = {
  name: '${namePrefix}-rsv'
  location: location
  tags: tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

output vmName string = vm.name
output loadBalancerPublicIp string = lbPip.properties.ipAddress
output recoveryVaultName string = recoveryVault.name
