Class VrrpInstance {
    [int]$Id
    [string]$Version
    [string[]]$Address
    [bool]$AcceptMode = $false
    [bool]$FabricRouteMode = $false
    [bool]$Enable = $false

    ##################################### Initiators #####################################
    # Initiator
    VrrpInstance() {
    }
}
