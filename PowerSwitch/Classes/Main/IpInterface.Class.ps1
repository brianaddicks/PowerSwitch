Class IpInterface {
    [string]$Name
    [string]$Description
    [string[]]$IpAddress
    [string]$VlanId
    [string[]]$IpHelper
    [bool]$IpHelperEnabled

    [bool]$Enabled
    [bool]$IpRedirectsEnabled = $true

    # multicast
    [string]$PimMode

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
