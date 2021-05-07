function Get-CiscoStaticRoute {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoStaticRoute:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup Return Object
    $ReturnObject = @()

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

        # ip route <network> <mask> <nexthop>
        $EvalParams.Regex = [regex] '^ip\ route\ (?<network>.+?)\ (?<mask>.+?)\ (?<gateway>\d+\.\d+\.\d+\.\d+)'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $Destination = $Eval.Groups['network'].Value + '/' + (ConvertTo-MaskLength $Eval.Groups['mask'].Value)

            $new = [IpRoute]::new()
            $new.Destination = $Destination
            $new.NextHop = $Eval.Groups['gateway'].Value
            $new.Type = 'static'

            Write-Verbose "$VerbosePrefix IpRoute Found: $($new.Destination)"

            $ReturnObject += $new
            continue
        }

        # ip default-gateway <nexthop>
        $EvalParams.Regex = [regex] '^ip\ default-gateway\ (.+)'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {

            $new = [IpRoute]::new()
            $new.Destination = '0.0.0.0/0'
            $new.NextHop = $Eval
            $new.Type = 'static'

            Write-Verbose "$VerbosePrefix IpRoute Found: $($new.Destination)"

            $ReturnObject += $new
            continue
        }
    }

    return $ReturnObject
}