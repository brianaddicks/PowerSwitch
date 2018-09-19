function Get-EosDiscoveryNeighbor {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosDiscoveryNeighbor:"

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
            if ($KeepGoing) {
                Write-Verbose "$VerbosePrefix $i`: neighbor output complete"
                break
            } else {
                continue
            }
        }

        ###########################################################################################
        # Check for the Section

        $Regex = [regex] 'show neighbors( wide)?$'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: 'show neighbors wide' found"
            $OutputStart = $true
            continue
        }

        if ($OutputStart) {
            $Regex = [regex] '^-+$'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                Write-Verbose "$VerbosePrefix $i`: neighbor output starting"
                $KeepGoing = $true
                continue
            }
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # vlan create
            $EvalParams.Regex = [regex] "^(?<localport>.+?)\ +(?<deviceid>.+?)\ +(?<remoteport>[^\ ]+?)?\ +(?<type>[^\ ]+?[dD][pP])\ +((?<networkaddress>.+?)\ )?"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $global:eval = $eval
                Write-Verbose "$VerbosePrefix $i`: neighbor found"
                $new = "" | Select-Object LocalPort, DeviceId, RemotePort, Type, NetworkAddress

                $new.LocalPort = $Eval.Groups['localport'].Value
                $new.DeviceId = $Eval.Groups['deviceid'].Value
                $new.RemotePort = $Eval.Groups['remoteport'].Value
                $new.Type = $Eval.Groups['type'].Value
                $new.NetworkAddress = $Eval.Groups['networkaddress'].Value

                $ReturnArray += $new
            }

            $Regex = [regex] '^$'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                Write-Verbose "$VerbosePrefix $i`: neighbor output complete"
                break
            }
        }
    }
    return $ReturnArray
}