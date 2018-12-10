Class SpantreeConfig {
    [int]$Priority = 32768
    [bool]$Enabled
    [string]$Mode
    [string[]]$AdminEdgePorts
    [string[]]$NonAdminEdgePorts
    [string[]]$AdminDisabledPorts
    [string[]]$AdminEnabledPorts
    [string[]]$AutoEdgeEnabled
    [string[]]$SpanGuardEnabled

    ##################################### Initiators #####################################
    # Initiator
    SpantreeConfig() {
    }
}
