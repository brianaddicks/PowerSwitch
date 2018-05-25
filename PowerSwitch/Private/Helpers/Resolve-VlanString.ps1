function Resolve-VlanString {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
        [String]$VlanString,
        
        [Parameter(Mandatory=$True,Position=0)]
        [ValidateSet("Eos")]
		[String]$SwitchType
	)
	
    $VerbosePrefix = "Resolve-VlanString: "
    
    $ReturnArray = @()
    switch ($SwitchType) {
        'Eos' {
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

    $ReturnArray
}