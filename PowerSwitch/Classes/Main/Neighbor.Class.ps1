Class Neighbor {
    [string]$LocalPort
    [string]$RemotePort
    [string]$DeviceId
    [string]$DeviceName
    [string]$DeviceDescription
    [string]$IpAddress
    [string[]]$CapabilitiesSupported
    [string[]]$CapabilitiesEnabled

    [bool]$LinkLayerDiscoveryProtocol = $false
    [bool]$CabletronDiscoveryProtocol = $false
    [bool]$CiscoDiscoveryProtocol = $false
    [bool]$ExtremeDiscoveryProtocol = $false

    ##################################### Initiators #####################################
    # Initiator
    Neighbor() {
    }
}
