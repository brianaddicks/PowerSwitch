Class IpInterface {
    [string]$Name
    [string]$VirtualRouter
    [string]$Description
    [string[]]$IpAddress
    [string]$VlanId
    [string[]]$IpHelper
    [bool]$IpHelperEnabled

    [bool]$Enabled
    [bool]$IpRedirectsEnabled = $true

    # multicast
    [string]$PimMode
    [bool]$PimPassive

    # ospf
    [string]$OspfArea
    [bool]$OspfPassive

    # access list
    [string]$AccessList
    [string]$AccessListDirection

    #EXOS
    [bool]$IpForwardingEnabled
    [bool]$IpMulticastForwardingEnabled

    # Vrrp
    [psobject[]]$VrrpInstance

    ##################################### Initiators #####################################
    # Initiator
    IpInterface([string]$Name) {
        $this.Name = $Name
    }
}
