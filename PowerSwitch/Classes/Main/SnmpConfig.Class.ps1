Class SnmpUser {
    [string]$Name
    [string]$AuthType
    [string]$PrivType

    ##################################### Initiators #####################################
    # Initiator
    SnmpUser() {
    }
}

Class SnmpGroup {
    [string]$Name
    [string[]]$User
    [int]$Version

    ##################################### Initiators #####################################
    # Initiator
    SnmpGroup() {
    }
}

Class SnmpView {
    [string]$Name
    [string[]]$IncludedOid
    [string[]]$ExcludedOid

    ##################################### Initiators #####################################
    # Initiator
    SnmpView() {
    }
}

Class SnmpAccess {
    [string]$Group
    [string]$ReadView
    [string]$WriteView
    [string]$NotifyView

    ##################################### Initiators #####################################
    # Initiator
    SnmpAccess() {
    }
}

Class SnmpConfig {
    [bool]$Enabled = $false
    [bool]$V1Enabled = $false
    [bool]$V2Enabled = $false
    [bool]$V3Enabled = $false

    [string]$EngineId
    [string[]]$Community

    [SnmpGroup[]]$Group
    [SnmpUser[]]$User
    [SnmpView[]]$View
    [SnmpAccess[]]$Access

    ##################################### Initiators #####################################
    # Initiator
    SnmpConfig() {
    }
}
