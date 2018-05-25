function Get-EosVlanConfig {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets Vlan Configuration from Eos (Extreme/Enterasys) switch "show conf" output.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[string]$ConfigPath
	)
    
    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosVlanConfig:"
    
    # Check for path and import
    if (Test-Path $ConfigPath) {
        $LoopArray = Get-Content $ConfigPath
    }

    # Setup return Array
    $ReturnArray = @()
	
    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
	
	$TotalLines = $LoopArray.Count
	$i          = 0 
	$StopWatch  = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down
	
	:fileloop foreach ($entry in $LoopArray) {
		$i++
		
		# Write progress bar, we're only updating every 1000ms, if we do it every line it takes forever
		
		if ($StopWatch.Elapsed.TotalMilliseconds -ge 1000) {
			$PercentComplete = [math]::truncate($i / $TotalLines * 100)
	        Write-Progress -Activity "Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
	        $StopWatch.Reset()
			$StopWatch.Start()
		}
		
		if ($entry -eq "") { continue }
		
		###########################################################################################
		# Check for the Section
		
		$Regex = [regex] '^#\ vlan$'
		$Match = Get-RegexMatch $Regex $entry
		if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: vlan: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry
            $EvalParams.ReturnGroupNumber = 1

            # vlan create
            $EvalParams.Regex = [regex] "^set\ vlan\ create\ (.+)"
            $Eval             = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: vlan: create"
                $ResolvedVlans = Resolve-VlanString -VlanString $Eval -SwitchType 'Eos'
                foreach ($r in $ResolvedVlans) {
                    $ReturnArray += [Vlan]::new($r)
                }
            }
            
            # vlan name
            $EvalParams.Remove('ReturnGroupNumber')
            $EvalParams.Regex = [regex] "set\ vlan\ name\ (?<id>\d+)\ (?<name>.+)"
            $Eval             = Get-RegexMatch @EvalParams
            if ($Eval) {
                $VlanId   = $Eval.Groups['id'].Value
                $VlanName = $Eval.Groups['name'].Value
                Write-Verbose "$VerbosePrefix $i`: vlan: id $VlanId = name $VlanName"
                $Lookup = $ReturnArray | Where-Object { $_.Id -eq $VlanId }
                if ($Lookup) {
                    $Lookup.Name = $VlanName
                } else {
                    Throw "$VerbosePrefix $i`: vlan: $VlanId not found in ReturnArray"
                }
            }

            $Regex = [regex] '^#'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                break
            }
        }
	}	
	return $ReturnArray
}