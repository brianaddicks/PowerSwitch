Class Neighbor {
    [string]$LocalPort
    [string]$RemotePort
    [string]$DeviceId
    [string]$DeviceName
    [string]$IpAddress
    [bool]$LinkLayerDiscoveryProtocol = $false
    [bool]$CabletronDiscoveryProtocol = $false
    [bool]$CiscoDiscoveryProtocol = $false
    [bool]$ExtremeDiscoveryProtocol = $false

    ##################################### Initiators #####################################
    # Initiator
    Neighbor() {
    }
}
