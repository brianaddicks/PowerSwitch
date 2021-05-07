function Get-PsTimeConfig {
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
    $VerbosePrefix = "Get-PsTimeConfig:"

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
        'Cisco' {
            $ReturnObject = Get-CiscoTimeConfig -ConfigArray $LoopArray
        }
        'HpComware' {
            $ReturnObject = Get-HpCwTimeConfig -ConfigArray $LoopArray
        }
        'HpAruba' {
            $ReturnObject = Get-HpArubaTimeConfig -ConfigArray $LoopArray
        }
        'ExtremeEos' {
            $ReturnObject = Get-EosTimeConfig -ConfigArray $LoopArray
        }
        default {
            Throw "$VerbosePrefix SwitchType not handled '$PsSwitchType'"
        }
    }


    return $ReturnObject
}