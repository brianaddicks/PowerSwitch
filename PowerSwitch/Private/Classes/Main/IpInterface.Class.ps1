Class IpInterface {
    [string]$Name
    [string]$Description
    [string[]]$IpAddress
    [string]$VlanId
    [string[]]$IpHelper

    [bool]$Enabled
    [bool]$IpRedirectsEnabled = $true

    # multicast
    [string]$PimMode

    ##################################### Initiators #####################################
    # Initiator
    IpInterface([string]$Name) {
        $this.Name = $Name
    }
}
