function Get-PsInventory {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateSet('ExtremeEos','Cisco')]
        [string]$PsSwitchType
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-PsInventory:"

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
            $ReturnObject = Get-EosInventory -ConfigArray $LoopArray
        }
        'Cisco' {
            $ReturnObject = Get-CiscoInventory -ConfigArray $LoopArray
        }
        default {
            Throw "$VerbosePrefix SwitchType not handled '$PsSwitchType'"
        }
    }

    if ($null -eq $ReturnObject) {
        switch ($PsSwitchType) {
            'ExtremeEos' {
                $ReturnObject = Get-EosInventoryFromConfig -ConfigArray $LoopArray
            }
            default {
                Throw "$VerbosePrefix SwitchType not handled for InventoryFromConfig'$PsSwitchType'"
            }
        }
    }


    return $ReturnObject
}