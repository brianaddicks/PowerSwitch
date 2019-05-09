function Resolve-PortString {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
        [String]$PortString,
        
        [Parameter(Mandatory=$True,Position=1)]
        [ValidateSet("Eos","Exos")]
		[String]$SwitchType
	)
	
    $VerbosePrefix = "Resolve-PortString: "
    
    $ReturnArray = @()
    switch ($SwitchType) {
        'Eos' {
            $BladeModuleRx = [regex] '(?<bm>\w+\.\d+\.)(?<number>\d+)'
            $SemicolonSplit = $PortString.Split(';')
            foreach ($sc in $SemicolonSplit) {
                $BladeModuleMatch = $BladeModuleRx.Match($sc)
                $BladeModule = $BladeModuleMatch.Groups['bm'].Value
                $CommaSplit = $sc.Split(',')
                foreach ($c in $CommaSplit) {
                    $DashSplit = $c.Split('-')
                    $BladeModuleMatch = $BladeModuleRx.Match($DashSplit[0])
                    if ($DashSplit.Count -eq 2) {
                        if ($BladeModuleMatch.Success) {
                            $Number = $BladeModuleMatch.Groups['number'].Value
                        } else {
                            $Number = $DashSplit[0]
                        }
                        for ( $d = [int]($Number); $d -le [int]($DashSplit[1]); $d++ ) {
                            $ReturnArray += "$BladeModule$d"
                        }
                    } else {
                        if ($BladeModuleMatch.Success) {
                            $ReturnArray += $DashSplit
                        } else {
                            $ReturnArray += "$BladeModule$DashSplit"
                        }
                    }
                }
            }
            continue
        }
        'Exos'{
            $BladeModuleRx = [regex] '(?<bm>\d+:)(?<number>\d+)'
            $CommaSplit = $PortString.Split(',')
                foreach ($c in $CommaSplit) {
                    $DashSplit = $c.Split('-')
                    $BladeModuleMatch = $BladeModuleRx.Match($c)
                    $BladeModule = $BladeModuleMatch.Groups['bm'].Value
                    if ($DashSplit.Count -eq 2) {
                        if ($BladeModuleMatch.Success) {
                            $Number = $BladeModuleMatch.Groups['number'].Value
                        } else {
                            $Number = $DashSplit[0]
                        }
                        for ( $d = [int]($Number); $d -le [int]($DashSplit[1]); $d++ ) {
                            $ReturnArray += "$BladeModule$d"
                        }
                    } else {
                        if ($BladeModuleMatch.Success) {
                            $ReturnArray += $DashSplit
                        } else {
                            $ReturnArray += "$BladeModule$DashSplit"
                        }
                    }
                }
                continue
        }
    }

    $ReturnArray
}