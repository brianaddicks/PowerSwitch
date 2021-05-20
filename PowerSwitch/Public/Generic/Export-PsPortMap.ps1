function Export-PsPortMap {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [Port[]]$Port = @($Port)
    )

    Begin {
        # It's nice to be able to see what cmdlet is throwing output isn't it?
        $VerbosePrefix = "Get-PsAaaConfig:"

        # check for ImportExcel Module
        if (!(Get-Module -ListAvailable ImportExcel)) {
            Throw "$VerbosePrefix cmdlet requires ImportExcel Module. Get it with 'Install-Module ImportExcel'"
        }

        # test for valid path
        $SplitPath = Split-Path -Path $Path
        $SplitPathLeaf = Split-Path -Path $Path -Leaf
        if (!(Test-Path -Path $SplitPath)) {
            Throw "$VerbosePrefix Path is invalid: $ResolvedPath"
        } else {
            $OutputPath = Join-Path -Path (Resolve-Path -Path $SplitPath) -ChildPath $SplitPathLeaf
        }

        $Output = $Port | Select-Object `
            Device,
            @{ Name = "PortName"; Expression = { $_.Name } },
            NewDevice,
            NewPortName,
            Alias,
            UntaggedVlan,
            VoiceVlan,
            @{ Name = "TaggedVlan"; Expression = { $_.TaggedVlan | Resolve-VlanString } }

        $Output | Export-Excel -Path $OutputPath -NoNumberConversion * -AutoSize
    }
}