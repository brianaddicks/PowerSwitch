function Get-PsAaaConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateSet('ExtremeEos')]
        [string]$PsSwitchType
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-PsAaaConfig:"

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
            $ReturnObject = Get-EosAaaConfig -ConfigArray $LoopArray
        }
        default {
            Throw "$VerbosePrefix SwitchType not handled '$PsSwitchType'"
        }
    }


    return $ReturnObject
}