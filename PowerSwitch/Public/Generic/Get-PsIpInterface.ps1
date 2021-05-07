function Get-PsIpInterface {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateSet('ExtremeEos', 'Cisco', 'HpComware', 'ExtremeExos')]
        [string]$PsSwitchType
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-PsIpInterface:"

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
            $ReturnObject = Get-CiscoIpInterface -ConfigArray $LoopArray
        }
        'HpComware' {
            $ReturnObject = Get-HpCwIpInterface -ConfigArray $LoopArray
        }
        'ExtremeEos' {
            $ReturnObject = Get-EosIpInterface -ConfigArray $LoopArray
        }
        'ExtremeExos' {
            $ReturnObject = Get-ExosIpInterface -ConfigArray $LoopArray
        }
        default {
            Throw "$VerbosePrefix SwitchType not handled '$PsSwitchType'"
        }
    }


    return $ReturnObject
}