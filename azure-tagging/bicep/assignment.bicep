param labId string
param definitionId string
resource assignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'owner-${labId}'
  properties: {
    displayName: 'Tagging ${labId}: OwnerTeam Audit'
    policyDefinitionId: definitionId
    enforcementMode: 'Default'
    parameters: { effect: {value: 'Audit'} }
    metadata: { LabId: labId }
  }
}
