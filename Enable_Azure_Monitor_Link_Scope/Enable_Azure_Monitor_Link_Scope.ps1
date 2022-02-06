# scope details
$scopeSubscriptionId = ""
$scopeResourceGroup = ""
$scopeName = "AzureMonitor"
$scopeProperties = @{
    accessModeSettings = @{
        queryAccessMode     = "Open"; 
        ingestionAccessMode = "PrivateOnly"
    } 
}
$virtualNetworkName = 'test'
$logAnalyticsWorkspaceID = ''
$GroupID = 'Name of the Group'

# login to Azure Portal
Connect-AzAccount

# select subscription
Select-AzSubscription -SubscriptionId $scopeSubscriptionId

# create private link scope resource
$scope = New-AzResource -Location "Global" -Properties $scopeProperties -ResourceName $scopeName `
    -ResourceType "Microsoft.Insights/privateLinkScopes" -ResourceGroupName $scopeResourceGroup -ApiVersion "2021-07-01-preview" -Force


$vnet = Get-AzVirtualNetwork -name $virtualNetworkName
$vnet.Subnets[0].PrivateEndpointNetworkPolicies = "Disabled"
$vnet | Set-AzVirtualNetwork

#Creating a lInk Service Connection
$linkServiceConnectionParam = @{
    Name                 = 'myConnection'
    PrivateLinkServiceId = $scope.ResourceId
    GroupID              = $GroupID
}
$privateEndpointConnection = New-AzPrivateLinkServiceConnection @linkServiceConnectionParam


#Creating a New Private Endpoint
$PrivateEndpointParam = @{
    ResourceGroupName            = $scopeResourceGroup
    Name                         = 'PrivateEndPoint'
    Location                     = 'australiaEast'
    Subnet                       = $vnet.Subnets[0]
    PrivateLinkServiceConnection = $privateEndpointConnection
}
New-AzPrivateEndpoint @PrivateEndpointParam

######Creating Private DNS and Integrating with Virtual Network
## Create private dns zone. ##
$privateDNSParam = @{
    ResourceGroupName = $scopeResourceGroup
    Name = 'privatelink.azurewebsites.net'
}
$zone = New-AzPrivateDnsZone @privateDNSParam

## Create dns network link. ##
$dnsNetworkLinkParam = @{
    ResourceGroupName = $scopeResourceGroup
    ZoneName = 'privatelink.monitor.azure.com'
    Name = 'AzureMonitorLink'
    VirtualNetworkId = $vnet.Id
}
$link = New-AzPrivateDnsVirtualNetworkLink @dnsNetworkLinkParam

## Create DNS configuration ##
$dnsConfig = @{
    Name = 'privatelink.monitor.azure.com'
    PrivateDnsZoneId = $zone.ResourceId
}
$config = New-AzPrivateDnsZoneConfig @dnsConfig

## Create DNS zone group. ##
$dnsZoneGroup = @{
    ResourceGroupName =  $scopeResourceGroup
    PrivateEndpointName = 'PrivateEndPoint'
    Name = 'AzureMonitorZone'
    PrivateDnsZoneConfig = $config
}
New-AzPrivateDnsZoneGroup @dnsZoneGroup


#Add Link Scope to the Log Analytics Workspace
New-AzInsightsPrivateLinkScopedResource -LinkedResourceId $logAnalyticsWorkspaceID -ResourceGroupName $scopeResourceGroup -ScopeName $GroupID 