function Get-EosRouteTable {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosRouteTable:"

    # Check for path and import
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
    $RouteTypeMap = @{}

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

        # start route table
        $EvalParams.Regex = [regex] '^IP\ Route\ Table'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: Found Route Table start"
            $KeepGoing = $true
        }

        if ($KeepGoing) {

            # type codes
            $Regex = [regex] '(?<code>[^\s]+?)-(?<type>.+?)(,|$)'
            $Eval = $Regex.Matches($entry)
            if ($Eval.Success) {
                Write-Verbose "$VerbosePrefix $i`: found codes"
                foreach ($match in $Eval) {
                    $Code = $match.Groups['code'].Value.Trim()
                    $Type = $match.Groups['type'].Value.Trim()
                    $RouteTypeMap.$Code = $Type
                }
            }

            # route table line
            $EvalParams.Regex = [regex] "^(?<type>\w+)\s+(?<destination>$IpRx\/\d+)\s+\[\d+\/\d+\]\s+\w+\s+(?<nexthop>$IpRx)?"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Type = ($Eval.Groups['type'].Value).Trim()
                $Destination = ($Eval.Groups['destination'].Value).Trim()
                $NextHop = ($Eval.Groups['nexthop'].Value).Trim()
                Write-Verbose "$VerbosePrefix $i`: route table: adding route $Destination -> $NextHop ($Type)"

                $NewEntry = [IpRoute]::new()
                $NewEntry.Type = $RouteTypeMap.$Type
                $NewEntry.Destination = $Destination
                $NewEntry.NextHop = $NextHop

                $ReturnArray += $NewEntry
            }

            $EvalParams.Regex = [regex] 'Number\ of\ routes'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break
            }
        }
    }

    if ($ReturnArray.Count -eq 0) {
        Throw "$VerbosePrefix No Route Table found, requires output from 'show ip route'"
    } else {
        return $ReturnArray
    }
}