Class LocalAccount {
    [string]$Name
    [string]$Type

    ##################################### Initiators #####################################
    # Initiator
    LocalAccount() {
    }
}

Class AuthServer {
    [string]$ServerIP
    [string]$Priority
    [string]$ServerPort
    [string]$PreSharedKey
    [bool]$NetLogon = $false
    [bool]$ManagementLogon = $false

    ##################################### Initiators #####################################
    # Initiator
    AuthServer() {
    }
}


Class AaaConfig {
    [AuthServer[]]$AuthServer
    [LocalAccount[]]$Account
    [bool]$RadiusEnabled = $false

    ##################################### Initiators #####################################
    # Initiator
    AaaConfig() {
    }
}
