Class Vlan {
    [string]$Name
    [int]$Id
    [string[]]$UntaggedPorts
    [string[]]$TaggedPorts

    ##################################### Initiators #####################################
    # Initiator
    Vlan([int]$VlanId) {
        $this.Id = $VlanId
    }
}
