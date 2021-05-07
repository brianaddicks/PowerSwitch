function Get-ExosTimeConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosTimeConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

<#
#>

    # Setup Return Object
    $ReturnObjectProps = @()
    $ReturnObjectProps += "SntpMode"
    $ReturnObjectProps += "Enabled"
    $ReturnObjectProps += "VirtualRouter"
    $ReturnObjectProps += "SntpServer"
    $ReturnObjectProps += "TimeZone"
    $ReturnObjectProps += "SummerTimeEnabled"
    $ReturnObjectProps += "SummerTimeStart"
    $ReturnObjectProps += "SummerTimeStop"
    $ReturnObjectProps += "SummerTimeOffset"

    $ReturnObject = "" | Select-Object $ReturnObjectProps
    $ReturnObject.SntpServer = @()
    $ReturnObject.SntpMode = 'broadcast'
    $ReturnObject.Enabled = $false
    $ReturnObject.VirtualRouter = 'VR-Mgmt'

    function CheckIfFinished() {
        $NotDone = $true
        foreach ($prop in $ReturnObjectProps) {
            if (($null -eq $ReturnObject.$prop) -or ($ReturnObject.$prop.Count -eq 0)) {
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
            Write-Progress -Activity "$VerbosePrefix Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
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

        # configure timezone name EST -300 autodst
        $EvalParams.Regex = [regex] "^configure\ timezone\ name\ (?<tzname>.+?)\ (?<offset>-?\d+)(?<dst>\ autodst)?"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObjectProps += "SntpMode"
            $ReturnObjectProps += "VirtualRouter"
            $ReturnObjectProps += "SntpServer"

            $ReturnObject.TimeZone = $Eval.Groups['tzname'].Value
            $ReturnObject.SummerTimeOffset = $Eval.Groups['offset'].Value
            if ($Eval.Groups['dst'].Success) {
                $ReturnObject.SummerTimeStart = 'autodst'
                $ReturnObject.SummerTimeStop = 'autodst'
                $ReturnObject.SummerTimeEnabled = $true
            }
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # enable sntp-client
        $EvalParams.Regex = [regex] '^enable\ sntp-client'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.Enabled = $true
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # configure sntp-client primary|secondary <server> vr VR-Default
        $EvalParams.Regex = [regex] '^configure\ sntp-client\ (?<priority>primary|secondary)\ (?<server>.+?)\ vr\ (?<vr>VR-Default)'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.SntpMode = 'unicast'
            $ReturnObject.VirtualRouter = $Eval.Groups['vr'].Value
            $ReturnObject.SntpServer += $Eval.Groups['server'].Value

            if (CheckIfFinished) { break fileloop }
            continue
        }
    }
    return $ReturnObject
}