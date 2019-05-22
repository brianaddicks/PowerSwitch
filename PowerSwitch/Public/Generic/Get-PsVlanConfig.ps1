function Get-PsVlanConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateSet('ExtremeEos', 'HpComware', 'HpAruba', 'Cisco')]
        [string]$PsSwitchType
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-PsVlanConfig:"

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
            $ReturnObject = Get-EosVlanConfig -ConfigArray $LoopArray
        }
        'HpComware' {
            $ReturnObject = Get-HpCwVlanConfig -ConfigArray $LoopArray
        }
        'Cisco' {
            $ReturnObject = Get-CiscoVlanConfig -ConfigArray $LoopArray
        }
        'HpAruba' {
            $ReturnObject = Get-HpArubaVlanConfig -ConfigArray $LoopArray
        }
        default {
            Throw "$VerbosePrefix SwitchType not handled '$PsSwitchType'"
        }
    }


    return $ReturnObject
}