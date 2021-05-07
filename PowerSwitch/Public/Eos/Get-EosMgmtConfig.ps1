function Get-EosMgmtConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosMgmtConfig:"

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
    $ReturnObject.SshEnabled = $false
    $ReturnObject.TelnetEnabled = $true
    $ReturnObject.WebviewEnabled = $true

    $WebviewComplete = $false
    $SshComplete = $false
    $TelnetComplete = $false

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
        # WebView
        $EvalParams = @{}
        $EvalParams.StringToEval = $entry

        $EvalParams.Regex = [regex] '^#(\ )?webview$'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: webview: config started"
            $WebViewKeepGoing = $true
            continue
        }

        if ($WebViewKeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # set webview disable
            $EvalParams.Regex = [regex] "^set\ webview\ disable"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: webview: disabled"
                $ReturnObject.WebviewEnabled = $false
                continue
            }

            $Regex = [regex] '^!'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                $WebviewComplete = $true
                if ($WebviewComplete -and $SshComplete -and $TelnetComplete) {
                    Write-Verbose "$VerbosePrefix $i`: webview: all sections complete"
                    break
                } else {
                    $WebViewKeepGoing = $false
                    Write-Verbose "$VerbosePrefix $i`: webview: config ended"
                    continue
                }
            }
        }

        ###########################################################################################
        # Ssh
        $EvalParams.Regex = [regex] '^#(\ )?ssh$'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: ssh: config started"
            $SshKeepGoing = $true
            continue
        }

        if ($SshKeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # set ssh enabled
            $EvalParams.Regex = [regex] "^set\ ssh\ enabled"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: ssh: enabled"
                $ReturnObject.SshEnabled = $true
                continue
            }

            $Regex = [regex] '^!'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                $SshComplete = $true
                if ($WebviewComplete -and $SshComplete -and $TelnetComplete) {
                    Write-Verbose "WebviewComplete: $WebviewComplete"
                    Write-Verbose "SshComplete: $SshComplete"
                    Write-Verbose "TelnetComplete: $TelnetComplete"
                    Write-Verbose "$VerbosePrefix $i`: ssh: all sections complete"
                    break
                } else {
                    $SshKeepGoing = $false
                    Write-Verbose "$VerbosePrefix $i`: ssh: config ended"
                    continue
                }
            }
        }

        ###########################################################################################
        # Telnet
        $EvalParams.Regex = [regex] '^#(\ )?telnet$'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: telnet: config started"
            $TelnetKeepGoing = $true
            continue
        }

        if ($TelnetKeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # set telnet disable inbound
            $EvalParams.Regex = [regex] "^set\ telnet\ disable\ inbound"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: telnet: disable"
                $ReturnObject.TelnetEnabled = $false
                continue
            }

            $Regex = [regex] '^!'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                $TelnetComplete = $true
                if ($WebviewComplete -and $SshComplete -and $TelnetComplete) {
                    Write-Verbose "$VerbosePrefix $i`: telnet: all sections complete"
                    break
                } else {
                    $TelnetKeepGoing = $false
                    Write-Verbose "$VerbosePrefix $i`: telnet: config ended"
                    continue
                }
            }
        }
    }
    return $ReturnObject
}