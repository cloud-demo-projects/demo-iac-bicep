@description('frontDoorName')
param frontDoorName string

@description('webAppNameWe')
param webAppNameWe string

@description('webAppNameNe')
param webAppNameNe string

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Premium_AzureFrontDoor'

@description('frontDoorWafEnabledState')
param frontDoorWafEnabledState bool = true

@description('frontDoorWafMode')
param frontDoorWafMode string = 'Prevention'

module frontdoorModule 'frontdoorcdn_module.bicep' = {
  name: 'frontdoorDeploy'
  params: {
    frontDoorName: frontDoorName
    frontDoorWafEnabledState: frontDoorWafEnabledState
    frontDoorWafMode: frontDoorWafMode
    frontDoorSkuName: frontDoorSkuName
    webAppNameNe: webAppNameNe
    webAppNameWe: webAppNameWe
  }
}
