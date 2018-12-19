function Get-PsDhcpSnoopingConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $True, Position = 1)]
        [string]$PsSwitchType
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-PsDhcpSnoopingConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Get the switch type
    switch ($PsSwitchType) {
        'ExtremeEos' {
            $ReturnObject = Get-EosDhcpSnoopingConfig -ConfigArray $LoopArray
        }
        'HpComware' {
            $ReturnObject = Get-HpDhcpSnoopingConfig -ConfigArray $LoopArray
        }
        'Cisco' {
            $ReturnObject = Get-CiscoDhcpSnoopingConfig -ConfigArray $LoopArray
        }
        'HpAruba' {
            $ReturnObject = Get-HpArubaDhcpSnoopingConfig -ConfigArray $LoopArray
        }
        default {
            Throw "$VerbosePrefix SwitchType not handled '$PsSwitchType'"
        }
    }


    return $ReturnObject
}