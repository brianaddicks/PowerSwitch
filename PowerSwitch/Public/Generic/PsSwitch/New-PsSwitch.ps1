function New-PsSwitch {
    [CmdletBinding()]
    Param (
    )

    BEGIN {
        $VerbosePrefix = "New-PsSwitch:"
    }

    PROCESS {
        $ReturnObject = [PsSwitch]::new()
    }

    END {
        $ReturnObject
    }
}
