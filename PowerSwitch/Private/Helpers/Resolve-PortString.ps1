function Resolve-PortString {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
        [String]$PortString,
        
        [Parameter(Mandatory=$True,Position=0)]
        [ValidateSet("Eos")]
		[String]$SwitchType
	)
	
    $VerbosePrefix = "Resolve-PortString: "
    
    $ReturnArray = @()
    switch ($SwitchType) {
        'Eos' {
            $BladeModuleRx = [regex] '(?<bm>\w+\.\d+\.)(?<number>\d+)'
            $SemicolonSplit = $PortString.Split(';')
            foreach ($sc in $SemicolonSplit) {
                Write-Verbose $sc
                $BladeModuleMatch = $BladeModuleRx.Match($sc)
                $BladeModule = $BladeModuleMatch.Groups['bm'].Value
                $CommaSplit = $sc.Split(',')
                foreach ($c in $CommaSplit) {
                    Write-Verbose $c
                    $DashSplit = $c.Split('-')
                    if ($DashSplit.Count -eq 2) {
                        $BladeModuleMatch = $BladeModuleRx.Match($DashSplit[0])
                        if ($BladeModuleMatch.Success) {
                            $Number = $BladeModuleMatch.Groups['number'].Value
                        } else {
                            $Number = $DashSplit[0]
                        }
                        Write-Verbose $DashSplit[0]
                        Write-Verbose $DashSplit[1]
                        for ( $d = [int]($Number); $d -le [int]($DashSplit[1]); $d++ ) {
                            $ReturnArray += "$BladeModule$d"
                        }
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