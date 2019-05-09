function Get-ExosVlanConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosVlanConfig:"

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
    $ReturnArray += [Vlan]::new(1)
    $ReturnArray[0].Name = "Default"

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

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry

        $EvalParams.Regex = [regex] "^#\ Module\ eaps\ configuration"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: eaps: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams.Regex = [regex] '^enable\ eaps$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: eaps: enabled"
                $ReturnObject.Enabled = $true
                continue
            }


            # create vlan "(vlan-name)"
            $EvalParams.Regex = [regex] "^configure\ eaps\ (?<domain>.+?)\ mode\ (?<mode>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = [Vlan]::new($NAMEVARIABLE)


                $Domain = $Eval.Groups['domain'].Value
                $Mode = $Eval.Groups['mode'].Value
                Write-Verbose "$VerbosePrefix $i`: eaps: domain '$Domain' mode: $Mode"
                $DomainLookup = $ReturnObject.Domain | Where-Object { $_.Name -eq $Domain }
                $DomainLookup.Mode = $Mode
                continue
            }


            # configure eaps <domain> mode <mode>
            $EvalParams.Regex = [regex] "^configure\ eaps\ (?<domain>.+?)\ mode\ (?<mode>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Domain = $Eval.Groups['domain'].Value
                $Mode = $Eval.Groups['mode'].Value
                Write-Verbose "$VerbosePrefix $i`: eaps: domain '$Domain' mode: $Mode"
                $DomainLookup = $ReturnObject.Domain | Where-Object { $_.Name -eq $Domain }
                $DomainLookup.Mode = $Mode
                continue
            }


            # next config section
            $EvalParams.Regex = [regex] "^(#)\ "
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break fileloop
            }
        }
    }

    return $ReturnObject
}