function Resolve-VlanString {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, ParameterSetName = 'string')]
        [String]$VlanString,

        [Parameter(Mandatory = $True, ParameterSetName = 'string')]
        [ValidateSet("Eos","Cisco")]
		[String]$SwitchType,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ParameterSetName = 'list')]
        [int[]]$VlanList
	)

    Begin {
        $VerbosePrefix = "Resolve-VlanString: "
        switch ($PsCmdlet.ParameterSetName) {
            'string' {
                $ReturnArray = @()
            }
            'list' {
                $ReturnArray = ""
            }
        }
    }

    Process {
        switch ($PsCmdlet.ParameterSetName) {
            'string' {
                switch ($SwitchType) {
                    { $_ -eq 'Eos' -or `
                    $_ -eq 'Cisco' } {
                        $CommaSplit = $VlanString.Split(',')
                        foreach ($c in $CommaSplit) {
                            $DashSplit = $c.Split('-')
                            if ($DashSplit.Count -eq 2) {
                                for ( $d = [int]($DashSplit[0]); $d -le [int]($DashSplit[1]); $d++ ) {
                                    $ReturnArray += $d
                                }
                            } else {
                                $ReturnArray += $DashSplit
                            }
                        }
                        continue
                    }
                }
            }
            'list' {
                # convert vlan to string
                $ThisVlan = [string]$VlanList

                if ($ReturnArray.Length -eq 0) {
                    $ReturnArray += $ThisVlan
                } elseif ([int]$ThisVlan -eq ([int]$LastVlan +1)) {
                    if ($ReturnArray -match '-\d+$') {
                        $ReturnArray = $ReturnArray -replace '-\d+$',"-$ThisVlan"
                    } else {
                        $ReturnArray += '-' + $ThisVlan
                    }
                } elseif ([int]$ThisVlan -gt ([int]$LastVlan +1)) {
                    $ReturnArray += ',' + $ThisVlan
                }

                $LastVlan = $ThisVlan
            }
        }

    }

    End {
<#         switch ($PsCmdlet.ParameterSetName) {
            'list' {
                if ([int]$ThisVlan -gt ([int]$LastVlan +1)) {
                    $ReturnArray += '-' + $ThisVlan
                } else {
                    $ReturnArray += ',' + $ThisVlan
                }
            }
        }
        Write-Verbose $LastVlan
        Write-Verbose $ThisVlan #>
        $ReturnArray
    }
}