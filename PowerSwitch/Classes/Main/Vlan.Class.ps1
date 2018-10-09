Class Vlan {
    [string]$Name
    [int]$Id
    [string[]]$UntaggedPorts
    [string[]]$TaggedPorts
    [bool]$Enabled = $true

    ##################################### Initiators #####################################
    # Initiator
    Vlan([int]$VlanId) {
        $this.Id = $VlanId
    }
}
