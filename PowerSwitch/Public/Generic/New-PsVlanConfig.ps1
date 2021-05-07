function New-PsVlanConfig {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [int]$VlanId
    )

    BEGIN {
        $VerbosePrefix = "New-PsVlanConfig:"
    }

    PROCESS {
        $ReturnObject = [Vlan]::new($VlanId)
    }

    END {
        $ReturnObject
    }
}
