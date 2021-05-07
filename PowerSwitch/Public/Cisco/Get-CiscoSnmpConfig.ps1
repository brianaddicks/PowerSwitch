function Get-CiscoSnmpConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoSnmpConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup Return Object
    $ReturnObject = @{}
    $ReturnObject.Community = @()
    $ReturnObject.AllowedHost = @()

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

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry
        $EvalParams.LineNumber = $i

        #############################################
        # Universal Commands

        # snmp-server community <community> <accesstype>
        $EvalParams.Regex = [regex] '^snmp-server\ community\ (?<community>.+?)\ (?<access>.+)'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $new = "" | Select-Object Community, Version, Access
            $new.Community = $Eval.Groups['community'].Value
            $new.Access = $Eval.Groups['access'].Value
            $new.Version = 'v2'
            $ReturnObject.Community += $new
            continue
        }

        # snmp-server host <server> <community>
        $EvalParams.Regex = [regex] '^snmp-server\ host\ (.+)\ '
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.AllowedHost += $Eval
            continue
        }
    }

    return $ReturnObject
}