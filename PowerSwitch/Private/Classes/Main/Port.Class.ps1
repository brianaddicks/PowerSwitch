Class Port {
    [string]$Name
    [string]$Alias

    [string]$NativeVlan
    [string]$UntaggedVlan
    [string[]]$TaggedVlan

    [string]$OperStatus
    [string]$AdminStatus
    [string]$Speed
    [string]$Duplex
    [string]$Type

    ##################################### Initiators #####################################
    # Initiator
    Port([string]$Name,[string]$Type) {
        $this.Name         = $Name
        if ($Type -ne "other") {
            $this.NativeVlan   = 1
            $this.UntaggedVlan = 1
        }
    }
}
