<#
.DESCRIPTION
The script will set create resource groups based on environment and location.

The script expects a rg-model.json file on the root directory.

.PARAMETER $Environment
Indicates in which environment resource group should be created.

.PARAMETER $Location
Indicates in which location resource group should be created.

.PARAMETER $TemplateFile
Indicates at which path bicep template is placed.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Provide the environment that will be used for the resource group deployment")]
    [ValidateNotNullOrEmpty()]
    [String]$Environment,

    [Parameter(Mandatory = $true, HelpMessage = "Provide the region that will be used for the resource group deployment")]
    [ValidateNotNullOrEmpty()]
    [String]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "Provide the Bicep template file path")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [String]$TemplateFile
)

# Retrieve config from the rg-model json file
$env = $Environment.Split('-')[2]
$model = (Get-Content -Path $PSScriptRoot\..\parameters\$env-$Location-rg.json | ConvertFrom-Json)
$currentSubId = (Get-AzContext).Subscription.Id
Write-Host $currentSubId

$resourcegroups = $model.resourcegroups 
$params = @{
    Location              = $Location
    locationFromTemplate  = $Location
    TemplateFile          = $TemplateFile
    ErrorAction           = "Stop"
}

foreach ($rg in $resourcegroups) {
    $params['nameFromTemplate']     = "resourceGroupDeployment-$(Get-Date -Format "yyyy-mm-dd-hh-mm-ss-fff")"
    $params['subscriptionId']       = $currentSubId
    $params['resourceGroupName']    = $rg.resourceGroupName
    $params['owner']                = $rg.owner    

    Write-Output $params | ConvertTo-Json
    $deployment = New-AzSubscriptionDeployment @params
    Write-Output "[$($rg.resourceGroupName)] Result: $($deployment.ProvisioningState)"

    if ($VerbosePreference -eq "Continue" -or $($env:AGENT_ID)) {
        $deployment
    }
}