function Get-PsSwitchType {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-PsSwitchType:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

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

        if ($entry -eq "") {
            continue
        }



        ###########################################################################################
        # HP Comware

        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry
        $EvalParams.Regex = [regex] "^\ +sysname\ (.+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNum 1
        if ($Eval) {
            $HpSysName = $Eval
            Write-Verbose "$VerbosePrefix HpSysName: $HpSysName"
            continue
        }

        if ($HpSysName) {
            $EvalParams.Regex = [regex] "(<|\[)$HpSysName(>|\])"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $PsSwitchType = "HpComware"
                break fileloop
            }
        }

        ###########################################################################################
        # HP Aruba

        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry
        $EvalParams.Regex = [regex] '^;\ .+\ Configuration\ Editor;'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $PsSwitchType = "HpAruba"
            break fileloop
        }

        ###########################################################################################
        # Cisco

        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry
        $EvalParams.Regex = [regex] "^Current\ configuration\ :\ \d+\ bytes"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $PsSwitchType = "Cisco"
            break fileloop
        }

        #region Enterasys
        ###########################################################################################

        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry
        $EvalParams.Regex = [regex] "^#(\ Chassis)?\ Firmware\ Revision:\ +\d+"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $PsSwitchType = "ExtremeEos"
            break fileloop
        }

        ###########################################################################################
        #endregion Enterasys

        #region Exos
        ###########################################################################################

        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry
        $EvalParams.Regex = [regex] "#\ Module\ devmgr\ configuration"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $PsSwitchType = "ExtremeExos"
            break fileloop
        }

        ###########################################################################################
        #endregion Exos
    }

    if (!($PsSwitchType)) {
        Throw "$VerbosePrefix unable to detect switch type with Get-PsSwitchType"
    }

    return $PsSwitchType
}