function New-PsIpInterface {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [string]$Name
    )

    BEGIN {
        $VerbosePrefix = "New-PsIpInterface:"
    }

    PROCESS {
        $ReturnObject = [IpInterface]::new($Name)
    }

    END {
        $ReturnObject
    }
}
