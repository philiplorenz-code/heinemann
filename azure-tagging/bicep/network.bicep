param location string
param labId string
param group string
param index int
param scenarios array
resource nsgs 'Microsoft.Network/networkSecurityGroups@2024-05-01' = [for n in range(0,2): {
  name: 'nsg-${labId}-${group}-${n+1}'
  location: location
  tags: scenarios[n+1].tags
  properties: { securityRules: [] }
}]
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${labId}-${group}'
  location: location
  tags: scenarios[0].tags
  properties: {
    addressSpace: { addressPrefixes: ['10.${index+71}.0.0/16'] }
    enableDdosProtection: false
    subnets: [{
      name: 'snet-empty'
      properties: union({addressPrefix: '10.${index+71}.0.0/24'}, group != 'legacy' ? {networkSecurityGroup: {id: nsgs[0].id}} : {})
    }]
  }
}
resource rt 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-${labId}-${group}'
  location: location
  tags: scenarios[3].tags
  properties: { routes: [], disableBgpRoutePropagation: false }
}
