Class Port {
    [string]$Name
    [string]$Alias

    [int]$NativeVlan
    [int]$UntaggedVlan
    [int]$VoiceVlan
    [int[]]$TaggedVlan

    [string]$OperStatus
    [string]$AdminStatus
    [string]$Speed
    [string]$Duplex
    [string]$Type
    [string]$Mode
    [string]$Aggregate

    [string]$StpMode
    [bool]$BpduGuard = $false
    [bool]$NoNegotiate = $false

    [bool]$DhcpSnoopingTrust = $false
    ##################################### Initiators #####################################
    # Initiator

    Port([string]$Name) {
        $this.Name = $Name
        $this.NativeVlan = 1
        $this.UntaggedVlan = 1
    }

    Port([string]$Name, [string]$Type) {
        $this.Name = $Name
        $this.Type = $Type

        if (($Type -ne "other") -and ($Name -notmatch "(com|vsb)")) {
            $this.NativeVlan = 1
            $this.UntaggedVlan = 1
        }
    }
}
