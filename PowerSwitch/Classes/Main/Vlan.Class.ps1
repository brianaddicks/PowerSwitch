Class Vlan {
    [string]$Name
    [int]$Id
    [string[]]$UntaggedPorts
    [string[]]$TaggedPorts
    [bool]$Enabled = $true
    #Exos#
    [string]$Description

    ##################################### Initiators #####################################
    # Initiator
    Vlan([int]$VlanId) {
        $this.Id = $VlanId
    }

    Vlan([string]$VlanName) {
        $this.Name = $VlanName
    }
}
