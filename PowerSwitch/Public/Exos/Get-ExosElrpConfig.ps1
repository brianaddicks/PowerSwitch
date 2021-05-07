function Get-ExosElrpConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosElrpConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
    $ReturnObject = [ElrpConfig]::new()

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down

    # The following Rx will be ignored
    $IgnoreRx = @(
        '^#$'
    )

    :fileloop foreach ($entry in $LoopArray) {
        $i++

        # Write progress bar, we're only updating every 1000ms, if we do it every line it takes forever

        if ($StopWatch.Elapsed.TotalMilliseconds -ge 1000) {
            $PercentComplete = [math]::truncate($i / $TotalLines * 100)
            Write-Progress -Activity "$VerbosePrefix Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
            $StopWatch.Reset()
            $StopWatch.Start()
        }

        if ($entry -eq "") { continue }

        ###########################################################################################
        # Check for the Section

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry.Trim()

        $EvalParams.Regex = [regex] "^#\ Module\ elrp\ configuration"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: elrp: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # enable elrp-client
            $EvalParams.Regex = [regex] '^enable\ (elrp-client)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $ReturnObject.Enabled = $true
                continue
            }

            # configure elrp-client periodic vlan <vlan> ports <port> "(?x)
            $EvalParams.Regex = [regex] '(?sx)
                ^configure\ elrp-client\ periodic(\ vlan)?\ (?<vlan>.+?)\ ports\ (?<port>[^\ ]+)
                (\ interval\ (?<interval>\d+))?
                (\ (?<logandtrap>log(-and-trap)?))?
                (?<disableport>\ disable-port)?
                (?<ingress>\ ingress)?
                (?<permanent>\ permanent)?
                $'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = [ElrpVlanConfig]::new()
                $New.VlanName = $Eval.Groups['vlan'].Value
                $New.Port += $Eval.Groups['port'].Value

                if ($Eval.Groups['interval'].Success) {
                    $New.IntervalInSeconds = $Eval.Groups['interval'].Value
                } else {
                    $New.IntervalInSeconds = 1
                }

                if ($Eval.Groups['disableport'].Success) {
                    $New.DisablePort = $true
                }

                if ($Eval.Groups['ingress'].Success) {
                    $New.Ingress = $true
                }

                if ($Eval.Groups['permanent'].Success) {
                    $New.DisableDurationInSeconds = 0
                }

                if ($Eval.Groups['logandtrap'].Success) {
                    switch ($Eval.Groups['logandtrap'].Value) {
                        'log-and-trap' {
                            $New.Log = $true
                            $New.Trap = $true
                        }
                        'log' {
                            $New.Log = $true
                        }
                    }
                }

                $ReturnObject.Vlan += $New
                continue
            }

            # configure elrp-client disable-port exclude <port>
            $EvalParams.Regex = [regex] '^configure\ elrp-client\ disable-port\ exclude\ (.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $ReturnObject.ExcludedPorts += $Eval
                continue
            }

            # ignored lines
            foreach ($Rx in $IgnoreRx) {
                $EvalParams.Regex = [regex] $Rx
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    continue fileloop
                }
            }

            # lines not processed
            Write-Verbose "$VerbosePrefix $i`: $entry"

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