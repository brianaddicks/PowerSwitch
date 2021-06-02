function Get-CiscoPoeModule {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoPoeModule:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $ReturnObject = @()
    $ShowModule = $false
    $ShowInventory = $false

    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"

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
        # Check for the Section

        # stacking
        $Regex = [regex] '#show\spower\sinline$'
        $Eval = Get-RegexMatch $Regex $entry
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: power inline output started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry

            # Module   Available     Used     Remaining
            #           (Watts)     (Watts)    (Watts)
            # ------   ---------   --------   ---------
            # 1          1360.0      654.2       705.8
            $EvalParams.Regex = [regex] "^(?<module>\d+)\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: poe module found"
                $ReturnObject += $Eval
                continue
            }

            # Gi0/1     auto   on         15.4    Ieee PD             3     15.4
            $EvalParams.Regex = [regex] "^Gi(\d+)\/\d+\ +auto\ +(on|off)\ +\d+\.\d+\s +.+?\d+\ +\d+\.\d+"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: poe module found"
                $ReturnObject += $Eval
                continue
            }
        }
    }
    return $ReturnObject | Select-Object -Unique
}