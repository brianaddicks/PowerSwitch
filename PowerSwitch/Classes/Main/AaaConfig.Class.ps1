Class AaaConfig {
    [psobject[]]$AuthServer
    [bool]$RadiusEnabled = $false

    ##################################### Initiators #####################################
    # Initiator
    AaaConfig() {
    }
}
