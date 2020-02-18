function Get-EosPortAlias {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosPortAlias:"

    # Check for path and import
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

        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry

        # start route table
        $EvalParams.Regex = [regex] '^#\ port'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: port config: section started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # end of section
            $EvalParams.Regex = [regex] '^!$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: port config: section complete"
                break
            }

            # set port alias ge.2.1 "uplink idf"
            # set port alias ge.2.3 NAC
            $EvalParams.Regex = [regex] "^set\ port\ alias\ (?<port>.+?)\ (?<alias>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $NewEntry = [Port]::new($Eval.Groups['port'].Value)
                $NewEntry.Alias = $Eval.Groups['alias'].Value

                $ReturnArray += $NewEntry
                continue
            }
        }
    }

    if ($ReturnArray.Count -eq 0) {
        Throw "$VerbosePrefix No Route Table found, requires output from 'show ip route'"
    } else {
        return $ReturnArray
    }
}