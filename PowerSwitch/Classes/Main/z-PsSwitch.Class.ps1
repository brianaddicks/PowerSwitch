Class PsSwitch {
    [string]$OperatingSystem
    [Vlan[]]$Vlan
    [Port[]]$Port
    [IpInterface[]]$IpInterface
    [IpRoute[]]$IpRoute

    #region Initiators
    ########################################################################

    # empty initiator
    PsSwitch() {
    }

    ########################################################################
    #endregion Initiators
}
