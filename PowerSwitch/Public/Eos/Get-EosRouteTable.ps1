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
    $IpInterface = Get-EosIpInterface -ConfigArray $LoopArray
    Write-Verbose "$VerbosePrefix $($IpInterface.Count) IpInterfaces found"

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
        $EvalParams.Regex = [regex] '(^(INET|IP)\ (R|r)oute\ (T|t)able|#show\ ip\ route$)'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: Found Route Table start"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # end of section
            $EvalParams.Regex = [regex] '(Number\ of\ routes|->)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: route table: section complete"
                break
            }

            # type codes
            $Regex = [regex] '(?<code>[^\s]+?)\s?-\s?(?<type>.+?)(,|$)'
            $Eval = $Regex.Matches($entry)
            if ($Eval.Success) {
                Write-Verbose "$VerbosePrefix $i`: found codes"
                foreach ($match in $Eval) {
                    $Code = $match.Groups['code'].Value.Trim()
                    $Type = $match.Groups['type'].Value.Trim()
                    $RouteTypeMap.$Code = $Type
                    continue
                }
            }

            # route table line securestack router context
            $EvalParams.Regex = [regex] "^(?<type>[\*\w]+)\s+(?<destination>$IpRx\/\d+)\s\[\d+\/\d+\]\s(via\s+(?<nexthop>$IpRx)|directly)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Type = ($Eval.Groups['type'].Value).Trim()
                $Destination = ($Eval.Groups['destination'].Value).Trim()
                $NextHop = ($Eval.Groups['nexthop'].Value).Trim()
                Write-Verbose "$VerbosePrefix $i`: route table: securestack with router context: adding route $Destination -> $NextHop ($Type)"

                $NewEntry = [IpRoute]::new()
                $NewEntry.Type = $RouteTypeMap.$Type
                $NewEntry.Destination = $Destination

                # Lookup IP Interface
                if ($NewEntry.Type -eq 'connected') {
                    Write-Verbose "$VerbosePrefix $i`: type is connected, looking for IpInterface"
                    foreach ($ip in $IpInterface.IpAddress) {
                        $ThisIpInterface = $IpInterface | Where-Object { Test-IpInRange -ContainingNetwork $Destination -ContainedNetwork $ip }
                        if ($ThisIpInterface) {
                            $NewEntry.NextHop = $ip -replace '/\d+', ''

                        }
                    }
                } else {
                    $NewEntry.NextHop = $NextHop
                }

                $ReturnArray += $NewEntry
                continue
            }

            # route table line 7100
            $EvalParams.Regex = [regex] "^(?<type>\w+)\s+(?<destination>$IpRx\/\d+)\s+\[\d+\/\d+\]\s+\w+\s+(?<nexthop>$IpRx)?"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Type = ($Eval.Groups['type'].Value).Trim()
                $Destination = ($Eval.Groups['destination'].Value).Trim()
                $NextHop = ($Eval.Groups['nexthop'].Value).Trim()
                Write-Verbose "$VerbosePrefix $i`: route table: 7100: adding route $Destination -> $NextHop ($Type)"

                $NewEntry = [IpRoute]::new()
                $NewEntry.Type = $RouteTypeMap.$Type
                $NewEntry.Destination = $Destination
                $NewEntry.NextHop = $NextHop

                $ReturnArray += $NewEntry
                continue
            }

            # route table line securestack non-router context
            $EvalParams.Regex = [regex] "^(?<destination>$IpRx\/\d+)\s+(?<nexthop>$IpRx)\s+(?<type>\w+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Type = ($Eval.Groups['type'].Value).Trim()
                $Destination = ($Eval.Groups['destination'].Value).Trim()
                $NextHop = ($Eval.Groups['nexthop'].Value).Trim()
                Write-Verbose "$VerbosePrefix $i`: route table: securestack non-router context: adding route $Destination -> $NextHop ($Type)"

                $RouteTypeMap = @{
                    'UG' = 'static'
                    'UC' = 'connected'
                }

                $NewEntry = [IpRoute]::new()
                $NewEntry.Type = $RouteTypeMap.$Type
                $NewEntry.Destination = $Destination
                $NewEntry.NextHop = $NextHop

                $ReturnArray += $NewEntry
                continue
            }
        }
    }

    if ($ReturnArray.Count -eq 0) {
        Throw "$VerbosePrefix No Route Table found, requires output from 'show ip route'"
    } else {
        return $ReturnArray
    }
}