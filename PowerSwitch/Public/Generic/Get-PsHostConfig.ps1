function Get-PsHostConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $True, Position = 1)]
        [string]$PsSwitchType,

        [Parameter(Mandatory = $False)]
        [string]$ExosManagementIpAddress
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-PsHostConfig:"

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
        'HpComware' {
            $ReturnObject = Get-HpCwHostConfig -ConfigArray $LoopArray
        }
        'Cisco' {
            $ReturnObject = Get-CiscoHostConfig -ConfigArray $LoopArray
        }
        'ExtremeEos' {
            $ReturnObject = Get-EosHostConfig -ConfigArray $LoopArray
        }
        'ExtremeExos' {
            $ReturnObject = Get-ExosHostConfig -ConfigArray $LoopArray -ManagementIpAddress $ExosManagementIpAddress
        }
        default {
            Throw "$VerbosePrefix SwitchType not handled '$PsSwitchType'"
        }
    }


    return $ReturnObject
}