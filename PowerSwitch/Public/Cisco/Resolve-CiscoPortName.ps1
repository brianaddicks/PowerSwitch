function Resolve-CiscoPortName {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True,ValueFromPipeline = $true)]
        [String]$PortName
	)

    Begin {
        $VerbosePrefix = "Resolve-CiscoPortName: "
        $ReturnArray = @()

        # short name data
        $ShortPortNameRx = [regex] '^(?<name>\w{2})(?<number>\d+((\/\d+)+)?)$'
        $ShortNameToLongName = @{
            'Te' = 'TenGigabitEthernet'
            'Gi' = 'GigabitEthernet'
            'Fa' = 'FastEthernet'
        }
    }

    Process {
        $ShortPortNameMatch = $ShortPortNameRx.Match($PortName)
        if ($ShortPortNameMatch.Success) {
            $ShortName = $ShortPortNameMatch.Groups['name'].Value
            $PortNumber = $ShortPortNameMatch.Groups['number'].Value
            $LongName = $ShortNameToLongName.$ShortName + $PortNumber
            $ReturnArray += $LongName
        }

        if (-not $LongName) {
            Throw "$VerbosePrefix unable to resolve $PortName"
        }
    }

    End {
        $ReturnArray
    }
}