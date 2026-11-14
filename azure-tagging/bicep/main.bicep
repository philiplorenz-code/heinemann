targetScope = 'subscription'
param labId string
param expiresOn string
param location string = 'northeurope'
param scenarios array
param createPolicy bool = true
var groups = ['development', 'production', 'legacy']
var environments = ['dev', 'prod', 'test']
resource rgs 'Microsoft.Resources/resourceGroups@2024-03-01' = [for (group, i) in groups: {
  name: 'rg-tagging-demo-${labId}-${group}'
  location: location
  tags: {
    Application: 'order-api'
    OwnerTeam: 'platform-orders'
    CostCenter: 'CC4711'
    Environment: environments[i]
    LabId: labId
    Purpose: 'tagging-demo'
    ExpiresOn: expiresOn
  }
}]
resource ownerPolicy 'Microsoft.Authorization/policyDefinitions@2023-04-01' = if (createPolicy) {
  name: 'tagging-owner-${labId}'
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Tagging ${labId}: OwnerTeam absent or empty'
    metadata: { category: 'Tags', LabId: labId }
    parameters: {
      effect: { type: 'String', allowedValues: ['Audit', 'Deny'], defaultValue: 'Audit' }
    }
    policyRule: {
      if: { anyOf: [ { field: 'tags[\'OwnerTeam\']', exists: 'false' }, { field: 'tags[\'OwnerTeam\']', equals: '' } ] }
      then: { effect: '[parameters(\'effect\')]' }
    }
  }
}
module networks 'network.bicep' = [for (group, i) in groups: {
  name: 'network-${labId}-${group}'
  scope: rgs[i]
  params: {
    location: location
    labId: labId
    group: group
    index: i
    scenarios: filter(scenarios, s => s.group == group)
  }
}]
module assignments 'assignment.bicep' = [for (group, i) in groups: if (createPolicy) {
  name: 'audit-${labId}-${group}'
  scope: rgs[i]
  params: { labId: labId, definitionId: ownerPolicy.id }
}]
output resourceGroups array = [for (group,i) in groups: rgs[i].id]
output policyDefinitionId string = createPolicy ? ownerPolicy.id : ''
