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
    [string]$Duplex = 'half'

    [string]$Type
    [string]$Mode

    [string]$Aggregate
    [string]$AggregateAlgorithm
    [bool]$LacpEnabled

    [string]$MirrorName
    [string]$MirrorStatus
    [string]$MirrorSource
    [string]$MirrorDestination

    [string]$StpMode
    [bool]$BpduGuard = $false
    [bool]$NoNegotiate = $false
    [bool]$JumboEnabled = $false
    [bool]$PoeDisabled = $false

    [bool]$DhcpSnoopingTrust = $false
    [int]$Mtu = 1500
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
