function Get-CiscoRouteTable {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoRouteTable:"

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

    function Resolve-CiscoRouteType {
        [CmdletBinding(DefaultParametersetName = "path")]

        Param (
            [Parameter(Mandatory = $True, Position = 0)]
            [string]$RouteType
        )

        switch ($RouteType) {
            'D EX' {
                $RouteType = 'EX'
            }
        }

        $TypeMap = @{
            'L'  = 'Special Lookup'
            'C'  = 'connected'
            'S'  = 'static'
            'R'  = 'RIP'
            'M'  = 'mobile'
            'B'  = 'BGP'
            'D'  = 'EIGRP'
            'EX' = 'EIGRP external'
            'O'  = 'Special Lookup'
            'IA' = 'Special Lookup'
            'N1' = 'OSPF NSSA external type 1'
            'N2' = 'OSPF NSSA external type 2'
            'E1' = 'OSPF external type 1'
            'E2' = 'OSPF external type 2'
            'i'  = 'IS-IS'
            'su' = 'IS-IS summary'
            'L1' = 'IS-IS level-1'
            'L2' = 'IS-IS level-2'
            '*'  = 'candidate default'
            'U'  = 'per-user static route'
            'P'  = 'periodic downloaded static route'
            'H'  = 'NHRP'
            '+'  = 'replicated route'
            '%'  = 'next hop override'
        }

        $ResolvedRouteType = $TypeMap.$RouteType
        if ($ResolvedRouteType -eq 'Special Lookup') {

        }

        switch -Regex ($RouteType) {
            'IA' {
                $ResolvedRouteType = 'OSPF inter area'
            }
            'ia' {
                $ResolvedRouteType = 'IS-IS inter area'
            }
            'o' {
                $ResolvedRouteType = 'ODR'
            }
            'O' {
                $ResolvedRouteType = 'OSPF'
            }
            'l' {
                $ResolvedRouteType = 'LISP'
            }
            'L' {
                $ResolvedRouteType = 'local'
            }
        }

        $ResolvedRouteType
    }


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

        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry
        $EvalParams.LineNumber = $i

        #############################################
        # Universal Commands

        <# S*    0.0.0.0/0 [100/0] via 10.254.231.15
            10.0.0.0/8 is variably subnetted, 6 subnets, 2 masks
        C        10.7.0.0/24 is directly connected, Vlan700
        L        10.7.0.6/32 is directly connected, Vlan700
        S        10.7.1.0/24 [1/0] via 10.7.0.1
        S        10.7.5.0/24 [1/0] via 10.7.0.5
        C        10.254.231.0/24 is directly connected, Vlan231
        L        10.254.231.16/32 is directly connected, Vlan231
        D EX    138.33.0.0/16 [170/28416] via 10.172.1.199, 5w2d, Vlan321 #>

        # ip route <network> <mask> <nexthop>
        $EvalParams.Regex = [regex] "^(?<type>.+?)(\*)?\s{2,}(?<destination>$IpRx\/\d+)\s(is\ directly\ connected|\[\d+\/\d+\]\ via\ (?<gateway>$IpRx))"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $new = [IpRoute]::new()
            $new.Destination = $Eval.Groups['destination'].Value
            $new.NextHop = $Eval.Groups['gateway'].Value
            $new.Type = Resolve-CiscoRouteType -RouteType $Eval.Groups['type'].Value

            Write-Verbose "$VerbosePrefix IpRoute Found: $($new.Destination)"

            $ReturnObject += $new
            continue
        }
    }

    return $ReturnObject
}