function Get-EosLinkFlapConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosLinkFlapConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup ReturnObject
    $ReturnObject = @{}
    $ReturnObject.Enabled = $false
    $ReturnObject.EnabledPorts = @()
    $ReturnObject.PortActionDisable = @()
    $ReturnObject.PortActionTrap = @()
    $ReturnObject.PortActionSyslog = @()

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

        $Regex = [regex] '^#(\ )?linkflap$'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: linkflap: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # set linkflap globalstate enable
            $EvalParams.Regex = [regex] "^set\ linkflap\ globalstate\ enable"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.Enabled = $true
            }

            # set linkflap action <port> <action>
            $EvalParams.Regex = [regex] "^set\ linkflap\ action\ (?<port>.+?)\ (?<action>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                switch ($Eval.Groups['action'].Value) {
                    'disableInterface' {
                        $ReturnObject.PortActionDisable += $Eval.Groups['port'].Value
                    }
                    'genSyslogEntry' {
                        $ReturnObject.PortActionSyslog += $Eval.Groups['port'].Value
                    }
                    'genTrap' {
                        $ReturnObject.PortActionTrap += $Eval.Groups['port'].Value
                    }
                    'all' {
                        $ReturnObject.PortActionDisable += $Eval.Groups['port'].Value
                        $ReturnObject.PortActionSyslog += $Eval.Groups['port'].Value
                        $ReturnObject.PortActionTrap += $Eval.Groups['port'].Value
                    }
                }
            }

            $EvalParams.ReturnGroupNumber = 1

            # set linkflap portstate enable <port>
            $EvalParams.Regex = [regex] "^set\ linkflap\ portstate\ enable\ (.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.EnabledPorts += $Eval
            }


            $Regex = [regex] '^#'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                break
            }
        }
    }
    return $ReturnObject
}