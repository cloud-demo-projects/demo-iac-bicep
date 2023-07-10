param subscriptionId string
param resourceGroupName string
param owner string
param location string
param name string

targetScope = 'subscription'

module rg_team '../starter/.bicep/resourceGroup.bicep' = {
  scope: subscription(subscriptionId)
  name: name
  params: {
    resourceGroupName : resourceGroupName
    owner : owner
    location : location
  }
}