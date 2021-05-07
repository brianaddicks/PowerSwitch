function Get-HpCwMgmtConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpCwMgmtConfig:"

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
    $ReturnObject.TelnetEnabled = $false
    $ReturnObject.WebviewEnabled = $false

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
        $EvalParams = @{}
        $EvalParams.StringToEval = $entry
        $EvalParams.LineNumber = $i

        # no telnet-server
        $EvalParams.Regex = [regex] '^\ telnet\ server\ enable'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.TelnetEnabled = $true
            continue
        }

        # web-managment
        $EvalParams.Regex = [regex] '^\ ip\ http\ enable'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.WebviewEnabled = $true
            continue
        }

        # ssh server enable
        $EvalParams.Regex = [regex] '^\ ssh\ server\ enable'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.SshEnabled = $true
            continue
        }
    }
    return $ReturnObject
}