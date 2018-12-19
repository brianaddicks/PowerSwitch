function Get-HpCwTimeConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpCwTimeConfig:"

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

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry

        # clock timezone <name> <offsetdirection> <offset>
        $EvalParams.Regex = [regex] '^\ clock\ timezone\ "(?<name>.+?)"\ (?<offsetdir>.+?)\ (?<offset>.+)'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $TzOffsetDirection = $Eval.Groups['offsetdir'].Value
            $TzOffset = $Eval.Groups['offset'].Value
            $TzOffsetRx = [regex] "(\d+):(\d+):(\d+)"
            $TzOffsetMatch = $TzOffsetRx.Match($TzOffset)
            $TzOffsetMinutes = ([int]$TzOffsetMatch.Groups[1].Value * 60) + [int]$TzOffsetMatch.Groups[2].Value
            if ($TzOffsetDirection -eq 'minus') {
                $TzOffsetMinutes *= -1
            }

            $new = [TimeConfig]::new()
            $new.TimeZoneOffsetMinutes = $TzOffsetMinutes
            $new.TimeZoneName = $Eval.Groups['name'].Value

            $ReturnArray += $new

            continue
        }

        # clock summer-time EST repeating 01:00:00 2015 March first Sunday 02:00:00 2015 November first Sunday  01:00:00
        $EvalParams.Regex = [regex] "^\ clock\ summer-time\ (?<timezone>.+?)\ repeating\ (?<starttime>.+?)\ (\d+)?\ (?<startmonth>.+?)\ (?<startnum>.+?)\ (?<startday>.+?)\ (?<stoptime>.+?)\ (\d+)?\ (?<stopmonth>.+?)\ (?<stopnum>.+?)\ (?<stopday>.+?)\ +(?<offset>.+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $TzName = $Eval.Groups['timezone'].Value
            $TzOffset = $Eval.Groups['offset'].Value
            $TzOffsetRx = [regex] "(\d+):(\d+):(\d+)"
            $TzOffsetMatch = $TzOffsetRx.Match($TzOffset)
            $TzOffsetMinutes = ([int]$TzOffsetMatch.Groups[1].Value * 60) + [int]$TzOffsetMatch.Groups[2].Value

            $new.SummerTimeOffset = $TzOffsetMinutes
            $new.SummerTimeStart = $Eval.Groups['startnum'].Value + '-' + $Eval.Groups['startday'].Value + '-' + $Eval.Groups['startmonth'].Value + '@' + $Eval.Groups['starttime'].Value
            $new.SummerTimeStop = $Eval.Groups['stopnum'].Value + '-' + $Eval.Groups['stopday'].Value + '-' + $Eval.Groups['stopmonth'].Value + '@' + $Eval.Groups['stoptime'].Value
            $new.SummerTimeEnabled = $true

            continue
        }

        # ntp-service unicast-server <server>
        $EvalParams.Regex = [regex] "^\ ntp-service\ unicast-server\ ([^\ ]+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $new.SntpMode = 'unicast'
            $new.SntpServer += $Eval

            continue
        }
    }
    return $ReturnArray
}