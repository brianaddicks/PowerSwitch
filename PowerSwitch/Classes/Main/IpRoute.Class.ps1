Class IpRoute {
    [string]$Destination
    [string]$NextHop
    [string]$Type
    [string]$Vrf
    [int]$Metric
    [int]$Distance
    [bool]$Active

    ##################################### Initiators #####################################
    # Initiator
    IpRoute() {
    }
}
