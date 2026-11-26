@description('Azure region for networking resources.')
param location string

@description('Name prefix for networking resources.')
param namePrefix string

@description('VNet address space CIDR.')
param vnetCidr string

@description('Subnet CIDR for App Service VNet Integration.')
param appServiceSubnetCidr string

@description('Subnet CIDR for private endpoints.')
param privateEndpointSubnetCidr string

@description('Subnet CIDR for private IaaS IIS VMs.')
param iaasWebSubnetCidr string

@description('Optional AzureBastionSubnet CIDR when enableBastion is true.')
param bastionSubnetCidr string = ''

@description('Deploy Azure Bastion for zero-public-RDP operator access.')
param enableBastion bool = false

@description('Common resource tags.')
param tags object

resource iaasNsg 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: '${namePrefix}-iaas-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowAzureLoadBalancerProbe'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowHttpsFromVnet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'DenyPublicRdp'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

var baseSubnets = [
  {
    name: 'snet-appservice-int'
    properties: {
      addressPrefix: appServiceSubnetCidr
      delegations: [
        {
          name: 'appServiceDelegation'
          properties: {
            serviceName: 'Microsoft.Web/serverFarms'
          }
        }
      ]
    }
  }
  {
    name: 'snet-private-endpoints'
    properties: {
      addressPrefix: privateEndpointSubnetCidr
      privateEndpointNetworkPolicies: 'Disabled'
    }
  }
  {
    name: 'snet-iaas-web'
    properties: {
      addressPrefix: iaasWebSubnetCidr
      networkSecurityGroup: {
        id: iaasNsg.id
      }
    }
  }
]

var bastionSubnet = enableBastion
  ? [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetCidr
        }
      }
    ]
  : []

resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: '${namePrefix}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetCidr]
    }
    subnets: concat(baseSubnets, bastionSubnet)
  }
}

resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-03-01' = if (enableBastion) {
  name: '${namePrefix}-bastion-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-03-01' = if (enableBastion) {
  name: '${namePrefix}-bastion'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ipcfg'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output appServiceSubnetId string = vnet.properties.subnets[0].id
output privateEndpointSubnetId string = vnet.properties.subnets[1].id
output iaasWebSubnetId string = vnet.properties.subnets[2].id
