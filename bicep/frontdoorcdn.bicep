/*
 * Frontdoor and CDN
 * This module deploys a global frontdoor with healthprobe, routingrule and a frontdoorwaf
 * https://docs.microsoft.com/en-us/azure/templates/microsoft.network/frontdoors?tabs=bicep
 */

@description('Name of the frontDoor')
param frontDoorName string 

@description('WAF Policy Name')
param frontDoorWafName string = ''

@description('The locations where the websites from the examplepipeline are located.')
param weblocations array = [
  'ne'
  'we'
]

@description('Date time field')
param dateTime string = utcNow('yyyyMMddHHmm')

@description('webAppName - use in case of single app')
param webAppName string = ''

@description('webAppNameWe - use in case of dual app')
param webAppNameWe string = ''

@description('webAppNameNe - use in case of dual app')
param webAppNameNe string = ''

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Premium_AzureFrontDoor'

@description('Specify the frontDoorWafEnabledState to true')
param frontDoorWafEnabledState bool = true

@description('Specify the frontDoorWafMode to Prevention due to Rabo Frontdoor H-001 policy')
param frontDoorWafMode string = 'Prevention'

var frontDoorOriginGroupName = 'MyOriginGroup'
var frontDoorOriginName = 'MyAppServiceOrigin'
var frontDoorRouteName = 'MyRoute'

// Resources
resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = [for (loc, i) in weblocations: {
  name: 'afd-endpoint${dateTime}-${loc}'
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}]

output deployedFrontDoorEndpoints array = [for (loc, i) in weblocations: {
  weblocation: loc
  fdName: frontDoorEndpoint[i].name
  fdId: frontDoorEndpoint[i].id
  frontDoorEndpointHostName: frontDoorEndpoint[i].properties.hostName
}]

resource wafpolicystandard 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = [for (loc, i) in weblocations: if (frontDoorSkuName == 'Standard_AzureFrontDoor') {
  // name: ( (frontDoorWafName == '') ? 'wafpolicystandard${loc}' : '${frontDoorWafName}${loc}' )
  name: 'wafpolicystandard${loc}'
  location: 'Global'
  tags: (frontDoorWafEnabledState ? json('{}') : json('{"AcceptedException_frontdoor-H-001": "AcceptedException_frontdoor-H-001"}'))
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: frontDoorWafEnabledState ? 'Enabled' : 'Disabled'
      mode: frontDoorWafMode
      customBlockResponseStatusCode: 403
      requestBodyCheck: 'Enabled'
    }
    customRules: {
      rules: [
        {
          name: 'blockchina'
          enabledState: 'Enabled'
          priority: 100
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'SocketAddr'
              operator: 'GeoMatch'
              negateCondition: false
              matchValue: [
                'CN'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'blockrussia'
          enabledState: 'Enabled'
          priority: 101
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'SocketAddr'
              operator: 'GeoMatch'
              negateCondition: false
              matchValue: [
                'RU'
                'BY'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'blockEvilBot'
          enabledState: 'Enabled'
          priority: 2
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RequestHeader'
              selector: 'User-Agent'
              operator: 'Contains'
              negateCondition: false
              matchValue: [
                'evilbot'
              ]
              transforms: [
                'Lowercase'
              ]
            }
          ]
          action: 'Block'
        }
      ]
    }
    managedRules: {
      managedRuleSets: []
    }
  }
}]

resource wafpolicypremium 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = [for (loc, i) in weblocations: if (frontDoorSkuName == 'Premium_AzureFrontDoor') {
  // name: ( (frontDoorWafName == '') ? 'wafpolicypremium${loc}' : '${frontDoorWafName}${loc}' )
  name: 'wafpolicypremium${loc}'
  location: 'Global'
  tags: (frontDoorWafEnabledState ? json('{}') : json('{"AcceptedException_frontdoor-H-001": "AcceptedException_frontdoor-H-001"}'))
  sku: {
    name: frontDoorSkuName
  }
  properties: {
    policySettings: {
      enabledState: frontDoorWafEnabledState ? 'Enabled' : 'Disabled'
      mode: frontDoorWafMode
      customBlockResponseStatusCode: 403
      requestBodyCheck: 'Enabled'
    }
    customRules: {
      rules: []
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.0'
          ruleSetAction: 'Block'
          ruleGroupOverrides: []
          exclusions: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
          exclusions: []
        }
      ]
    }
  }
}]

resource securitypolicy 'Microsoft.Cdn/profiles/securityPolicies@2021-06-01' = [for (loc, i) in weblocations: {
  name: '${frontDoorName}/${uniqueString(resourceGroup().id)}${i}'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: ((frontDoorSkuName == 'Premium_AzureFrontDoor') ? wafpolicypremium[i].id : wafpolicystandard[i].id)
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint[i].id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}]

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

// origins (in Azure FrontDoor Classic called Backendpool)
resource frontDoorOriginNe 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = if (!empty(webAppNameNe)) {
  name: '${frontDoorOriginName}ne'
  parent: frontDoorOriginGroup
  properties: {
    hostName: '${webAppNameNe}.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: '${webAppNameNe}.azurewebsites.net'
    priority: 1
    weight: 1000
  }
}

resource frontDoorOriginWe 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = if (!empty(webAppNameWe)) {
  name: '${frontDoorOriginName}we'
  parent: frontDoorOriginGroup
  properties: {
    hostName: '${webAppNameWe}.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: '${webAppNameWe}.azurewebsites.net'
    priority: 1
    weight: 1000
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = if (!empty(webAppName)) {
  name: 'frontDoorOriginName'
  parent: frontDoorOriginGroup
  properties: {
    hostName: '${webAppName}.azurewebsites.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: '${webAppName}.azurewebsites.net'
    priority: 1
    weight: 1000
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = [for (loc, i) in weblocations: {
  name: '${frontDoorRouteName}${loc}'
  parent: frontDoorEndpoint[i]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}]

output frontDoorEndpoint string = frontDoorEndpoint[0].properties.hostName
