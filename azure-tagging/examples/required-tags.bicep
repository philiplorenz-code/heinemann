targetScope = 'subscription'

@minLength(1)
param application string
@minLength(1)
param ownerTeam string
@minLength(1)
param costCenter string
@allowed(['dev', 'test', 'prod'])
param environment string
param location string = 'northeurope'

resource app 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${application}-${environment}'
  location: location
  tags: {
    Application: application
    OwnerTeam: ownerTeam
    CostCenter: costCenter
    Environment: environment
  }
}
