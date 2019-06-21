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
