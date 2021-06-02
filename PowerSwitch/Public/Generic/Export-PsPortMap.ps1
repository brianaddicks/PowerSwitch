function Export-PsPortMap {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory = $True)]
        [Port[]]$PortConfig,

        [Parameter(Mandatory = $false)]
        [Port[]]$PortStatus,

        [Parameter(Mandatory = $false)]
        [string]$DeviceName
    )

    Begin {
        # It's nice to be able to see what cmdlet is throwing output isn't it?
        $VerbosePrefix = "Export-PsPortMap:"

        # check for ImportExcel Module
        if (!(Get-Module -ListAvailable ImportExcel)) {
            Throw "$VerbosePrefix cmdlet requires ImportExcel Module. Get it with 'Install-Module ImportExcel'"
        }

        # test for valid path
        $SplitPath = Split-Path -Path $Path
        $SplitPathLeaf = Split-Path -Path $Path -Leaf
        if (!(Test-Path -Path $SplitPath)) {
            Throw "$VerbosePrefix Path is invalid: $SplitPath"
        } else {
            $OutputPath = Join-Path -Path (Resolve-Path -Path $SplitPath) -ChildPath $SplitPathLeaf
        }

        # add port status to port config
        foreach ($port in $PortStatus) {
            $ResolvedPortName = Resolve-CiscoPortName -PortName $port.Name
            $ConfigLookup = $PortConfig | Where-Object { $_.Name -eq $ResolvedPortName }
            $ConfigLookup.OperStatus = $port.OperStatus
            $ConfigLookup.Speed = $port.Speed
            $ConfigLookup.Duplex = $port.Duplex
            $ConfigLookup.Type = $port.Type
        }

        $Output = $PortConfig | Select-Object `
            @{ Name = 'Device'; Expression = { $DeviceName } },
            @{ Name = "PortName"; Expression = { $_.Name } },
            NewDevice,
            NewPortName,
            Aggregate,
            OperStatus,
            AdminStatus,
            Speed,
            Duplex,
            NoNegotiate,
            Type,
            Alias,
            UntaggedVlan,
            VoiceVlan,
            @{ Name = "TaggedVlan"; Expression = { $_.TaggedVlan | Resolve-VlanString } }

        $Output | Export-Excel -Path $OutputPath -NoNumberConversion * -AutoSize -ClearSheet -FreezeTopRow
    }
}