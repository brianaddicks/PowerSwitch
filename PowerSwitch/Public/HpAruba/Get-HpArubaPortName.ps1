function Get-HpArubaPortName {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpArubaPortName:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $ReturnArray = @()

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down

    # ResolvePortString
    function ResolvePortString ($portString) {
        $ReturnArray = @()
        $PortNameRx = [regex] '(\d+)\/(\d+)'
        $CommaSplit = $portString.Split(',')
        foreach ($c in $CommaSplit) {
            $DashSplit = $c.Split('-')
            if ($DashSplit.Count -eq 2) {
                $StartPort = $DashSplit[0]
                $StopPort = $DashSplit[1]
                $StackMember = $PortNameRx.Match($StartPort).Groups[1].Value
                $StartPort = [int]($PortNameRx.Match($StartPort).Groups[2].Value)
                $StopPort = [int]($PortNameRx.Match($StopPort).Groups[2].Value)
                for ($i = $StartPort; $i -le $StopPort; $i++) {
                    $ReturnArray += "$StackMember/$i"
                }
            } else {
                $ReturnArray += $c
            }
        }
        $ReturnArray
    }

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

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry
        $EvalParams.LineNumber = $i

        # vlan 1
        $EvalParams.Regex = [regex] '^vlan\ 1$'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix found vlan 1 on line $i"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry
            $EvalParams.LineNumber = $i

            # no untagged ports on multiple lines
            # no untagged <ports>
            $EvalParams.Regex = [regex] '(?s)^\s+no\ untagged'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose $Eval
                $NoUntagged = $true
                continue
            }

            if ($NoUntagged) {
                # ports
                $EvalParams.Regex = [regex] "^\s*(\d+.+)"
                $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
                if ($Eval) {
                    if ($PortString) {
                        $PortString += $Eval
                    } else {
                        $PortString = $Eval
                    }
                    Write-Verbose $PortString
                    continue
                }

                # end of no untagged
                $EvalParams.Regex = [regex] "^\s+untagged"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    $NoUntagged = $false
                    foreach ($port in (ResolvePortString $PortString)) {
                        $ReturnArray += [Port]::new($port)
                    }
                    Write-Verbose $Eval
                }
            }

            # untagged <ports>
            $EvalParams.Regex = [regex] '(?s)^\s+untagged\ (\d+.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose $Eval
                foreach ($port in (ResolvePortString $Eval)) {
                    $ReturnArray += [Port]::new($port)
                }
                continue
            }

            # stop loop
            $EvalParams.Regex = [regex] '^vlan'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose $Eval
                break fileloop
            }
        }
    }
    return $ReturnArray
}