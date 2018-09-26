function Get-EosTimeConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosTimeConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup Return Object
    $ReturnObjectProps = @()
    $ReturnObjectProps += "SntpMode"
    $ReturnObjectProps += "SntpServer"
    $ReturnObjectProps += "TimeZone"
    $ReturnObjectProps += "SummerTimeEnabled"
    $ReturnObjectProps += "SummerTimeStart"
    $ReturnObjectProps += "SummerTimeStop"
    $ReturnObjectProps += "SummerTimeOffset"

    $ReturnObject = "" | Select-Object $ReturnObjectProps
    $ReturnObject.SntpServer = @()
    $ReturnObject.SntpMode = 'broadcast'

    function CheckIfFinished() {
        $NotDone = $true
        foreach ($prop in $ReturnObjectProps) {
            if ($null -eq $ReturnObject.$prop) {
                $NotDone = $false
            }
        }
        Write-Verbose "$VerbosePrefix`: $i`: CheckIfFinished: $NotDone"
        return $NotDone
    }

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

        #############################################
        # Universal Commands

        # set timezone <name> <hour> <minute>
        $EvalParams.Regex = [regex] "^set\ timezone\ '(?<name>.+?)'\ (?<hour>[-\d]+)\ (?<minute>\d+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.TimeZone = ([int]($Eval.Groups['hour'].Value) * 60) + [int]($Eval.Groups['minute'].Value)
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # set summertime enable
        $EvalParams.Regex = [regex] '^set\ summertime\ enable'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.SummerTimeEnabled = $true
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # set summertime recurring second Sunday March 02:00 first Sunday November 02:00 60
        $EvalParams.Regex = [regex] '^set\ summertime\ recurring\ (?<startweek>.+?)\ (?<startday>.+?)\ (?<startmonth>.+?)\ (?<starttime>\d+:\d+)\ (?<stopweek>\w+?)\ (?<stopday>\w+?)\ (?<stopmonth>\w+?)\ (?<stoptime>\d+:\d+)\ (?<offset>\d+)'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $StartString = $Eval.Groups['startweek'].Value + '-'
            $StartString += $Eval.Groups['startday'].Value + '-'
            $StartString += $Eval.Groups['startmonth'].Value + '@'
            $StartString += $Eval.Groups['starttime'].Value

            $StopString = $Eval.Groups['stopweek'].Value + '-'
            $StopString += $Eval.Groups['stopday'].Value + '-'
            $StopString += $Eval.Groups['stopmonth'].Value + '@'
            $StopString += $Eval.Groups['stoptime'].Value

            $Offset = $Eval.Groups['offset'].Value

            $ReturnObject.SummerTimeStart = $StartString
            $ReturnObject.SummerTimeStop = $StopString
            $ReturnObject.SummerTimeOffset = $Offset

            if (CheckIfFinished) { break fileloop }
            continue
        }

        # set sntp client unicast
        $EvalParams.Regex = [regex] '^set\ sntp\ client\ unicast'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.SntpMode = 'unicast'
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # set sntp server <server>
        $EvalParams.Regex = [regex] "^set\ sntp\ server\ ($IpRx)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.SntpServer += $Eval
            if (CheckIfFinished) { break fileloop }
            continue
        }
    }

    return $ReturnObject
}