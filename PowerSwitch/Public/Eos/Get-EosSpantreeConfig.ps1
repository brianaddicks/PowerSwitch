function Get-EosSpantreeConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosSpantreeConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    $Ports = Get-EosPortName -ConfigArray $LoopArray

    # Setup ReturnObject
    $ReturnObject = @{}
    $ReturnObject.StpEnabled = $true
    $ReturnObject.StpMode = 'mstp'
    $ReturnObject.Priority = 32768
    $ReturnObject.AdminEdgePorts = @()
    $ReturnObject.NonAdminEdgePorts = $Ports
    $ReturnObject.AdminDisabledPorts = @()
    $ReturnObject.AdminEnabledPorts = $Ports
    $ReturnObject.AutoEdgeEnabled = $true
    $ReturnObject.SpanGuardEnabled = $false

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

        if ($entry -eq "") { continue }

        ###########################################################################################
        # Check for the Section

        $Regex = [regex] '^#(\ )?spantree$'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: spantree: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # set spantree autoedge disable
            $EvalParams.Regex = [regex] "^set\ spantree\ autoedge\ disable"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.AutoEdgeEnabled = $false
            }

            # set spantree spanguard enable
            $EvalParams.Regex = [regex] "^set\ spantree\ spanguard\ enable"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.SpanGuardEnabled = $true
            }

            $EvalParams.ReturnGroupNumber = 1

            # set spantree priority <priority>
            $EvalParams.Regex = [regex] "^set\ spantree\ priority\ (\d+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: spantree: priority"
                $ReturnObject.Priority = $Eval
            }

            # set spantree adminedge <port> true
            $EvalParams.Regex = [regex] "^set\ spantree\ adminedge\ (.+?)\ true"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.AdminEdgePorts += $Eval
                $ReturnObject.NonAdminEdgePorts = $ReturnObject.NonAdminEdgePorts | Where-Object { $_ -ne $Eval }
            }

            # set spantree portadmin <port> disable
            $EvalParams.Regex = [regex] "^set\ spantree\ portadmin\ (.+?)\ disable"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.AdminDisabledPorts += $Eval
            }

            # set spantree stpmode none
            $EvalParams.Regex = [regex] "^set\ spantree\ stpmode\ (.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.StpMode = $Eval
                $ReturnObject.StpEnabled = $false
            }

            # set spantree disable
            $EvalParams.Regex = [regex] "^set\ spantree\ (disable)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.StpEnabled = $false
                $ReturnObject.StpMode = 'none'
            }


            $Regex = [regex] '^#'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                Write-Verbose "$VerbosePrefix $i`: spantree: config complete"
                break
            }
        }
    }
    return $ReturnObject
}