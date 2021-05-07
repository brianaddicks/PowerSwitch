function Get-CiscoTimeConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoTimeConfig:"

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
        $EvalParams.Regex = [regex] "^clock\ timezone\ (?<tzname>.+)\ (?<tzoffset>.+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $TzName = $Eval.Groups['tzname'].Value
            $TzOffset = $Eval.Groups['tzoffset'].Value

            $new = [TimeConfig]::new()
            $new.TimeZoneOffsetMinutes = [int]$TzOffset * 60
            $new.TimeZoneName = $TzName
            $new.SummerTimeOffset = 60
            $new.SummerTimeStart = 'second-sunday-march@02:00'
            $new.SummerTimeStop = 'first-sunday-november@02:00'

            $ReturnArray += $new

            continue
        }

        # clock summer-time EST recurring
        $EvalParams.Regex = [regex] "^clock\ summer-time\ (?<tzname>.+)\ recurring"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNum 1
        if ($Eval) {
            $new.SummerTimeEnabled = $true
        }

        # ntp server 1.1.1.1
        $EvalParams.Regex = [regex] "^ntp\ server\ ($IpRx)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNum 1
        if ($Eval) {
            $new.SntpServer = $Eval
        }

    }
    return $ReturnArray
}