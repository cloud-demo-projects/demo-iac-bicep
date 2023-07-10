param location string
param resourceGroupName string
param owner string
targetScope = 'subscription'

resource RG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: resourceGroupName
  location: location
  tags: {
      Owner: owner
    }
}

output resourceGroupName string = RG.name
