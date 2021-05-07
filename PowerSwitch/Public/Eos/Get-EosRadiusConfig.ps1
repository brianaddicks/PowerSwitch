function Get-EosRadiusConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosRadiusConfig:"

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
    $ReturnObject.AccountingEnabled = $false
    $ReturnObject.Server = @()
    $ReturnObject.AccountingServer = @()

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

        $Regex = [regex] '^#(\ )?radius$'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: radius: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry
            $EvalParams.ReturnGroupNumber = 1

            # set radius enable
            $EvalParams.Regex = [regex] "^set\ radius\ (enable)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: radius: enabled"
                $ReturnObject.Enabled = $true
            }

            # set radius accounting enable
            $EvalParams.Regex = [regex] "^set\ radius\ accounting\ (enable)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: radius: accounting enabled"
                $ReturnObject.AccountingEnabled = $true
            }

            # set radius timeout <timeout>
            $EvalParams.Regex = [regex] "^set\ radius\ timeout\ (.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: radius: timeout: $Eval"
                $ReturnObject.Timeout = $Eval
            }

            # set radius accouting timeout <timeout>
            $EvalParams.Regex = [regex] "^set\ radius\ accounting\ timeout\ (.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: radius: accouting timeout: $Eval"
                $ReturnObject.AccoutingTimeout = $Eval
            }

            # set radius accounting retries <retries>
            $EvalParams.Regex = [regex] "^set\ radius\ accounting\ retries\ (.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: radius: accounting retries: $Eval"
                $ReturnObject.AccountingRetries = $Eval
            }

            # set radius accounting server <server> <port> <key>
            $EvalParams.Regex = [regex] "^set\ radius\ accounting\ server\ (?<server>.+?)\ (?<port>\d+)"
            $EvalParams.Remove("ReturnGroupNumber")
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: radius: accounting server: $Eval"
                $new = "" | Select-Object Server, Port
                $new.Server = $Eval.Groups['server'].Value
                $new.Port = $Eval.Groups['port'].Value

                $ReturnObject.AccountingServer += $new
            }

            # set radius server 1 10.250.2.15 1812 :60df61c965667ae9de5a1280eb125497e3ad54b9b67d0933dc422879e83e13687660dc63154ae90cdd: realm network-access
            $EvalParams.Regex = [regex] "^set\ radius\ server\ (?<priority>\d+)\ (?<server>.+?)\ (?<port>\d+)(.+?realm\ (?<realm>.+))?"
            $EvalParams.Remove("ReturnGroupNumber")
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new = "" | Select-Object Server, Port, Priority, Realm
                $new.Server = $Eval.Groups['server'].Value
                $new.Port = $Eval.Groups['port'].Value
                $new.Priority = $Eval.Groups['priority'].Value
                $new.Realm = $Eval.Groups['realm'].Value

                Write-Verbose "$VerbosePrefix $i`: radius: server: $($new.Server)"

                $ReturnObject.Server += $new
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