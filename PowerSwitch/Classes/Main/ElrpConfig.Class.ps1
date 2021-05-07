Class ElrpVlanConfig {
    [string]$VlanName
    [string[]]$Port
    [int64]$IntervalInSeconds

    [bool]$DisablePort = $false
    [int64]$DisableDurationInSeconds = 30

    [bool]$Log = $false
    [bool]$Trap = $false
    [bool]$Ingress = $false

    ##################################### Initiators #####################################
    # Initiator
    ElrpVlanConfig() {
    }
}

Class ElrpConfig {
    [bool]$Enabled = $false
    [ElrpVlanConfig[]]$Vlan
    [string[]]$ExcludedPorts

    ##################################### Initiators #####################################
    # Initiator
    ElrpConfig() {
    }
}