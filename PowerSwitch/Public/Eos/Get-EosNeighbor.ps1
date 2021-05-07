function Get-EosNeighbor {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosNeighbor:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
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

        if ($entry -eq "") {
            if ($InSlot) {
                Write-Verbose "$VerbosePrefix $i`: slot complete"
                $InSlot = $false
            }
            continue
        }

        ###########################################################################################
        # Check for the Section

        $Regex = [regex] '->show\ nei'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: neighbor output started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {

            # Look for section stop, this should match a new prompt string and nothing else
            $Regex = [regex] '->'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                Write-Verbose "$VerbosePrefix $i`: neighbor output complete"
                break
            }

            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry

            #region s-series
            #################################################################################

            # header for column lengths
            $EvalParams.Regex = [regex] "^(?<localport>\s+Port\s+)(?<deviceid>Device\sID\s+)(?<remoteport>Port\sID\s+)(?<type>Type\s+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: header found"
                $HeaderMatch = $Eval
                continue
            }

            #region s4psu
            #################################################################################


            <# [string]$LocalPort
            [string]$RemotePort
            [string]$DeviceId
            [string]$DeviceName
            [string]$DeviceDescription
            [string]$IpAddress
            [string[]]$CapabilitiesSupported
            [string[]]$CapabilitiesEnabled

            [bool]$LinkLayerDiscoveryProtocol = $false
            [bool]$CabletronDiscoveryProtocol = $false
            [bool]$CiscoDiscoveryProtocol = $false
            [bool]$ExtremeDiscoveryProtocol = $false #>

            # power supplies
            $EvalParams.Regex = [regex] "^[a-z]{2}\.\d+\.\d+"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $NewObject = [Neighbor]::new()
                $NewObject.LocalPort = ($entry.SubString($HeaderMatch.Groups['localport'].Index,$HeaderMatch.Groups['localport'].Length - 1)).Trim()
                $NewObject.DeviceId = ($entry.SubString($HeaderMatch.Groups['deviceid'].Index - 1,$HeaderMatch.Groups['deviceid'].Length - 1)).Trim()
                $NewObject.RemotePort = ($entry.SubString($HeaderMatch.Groups['remoteport'].Index - 1,$HeaderMatch.Groups['remoteport'].Length - 1)).Trim()

                if ($entry.Length -ge ($HeaderMatch.Groups['type'].Index + $HeaderMatch.Groups['type'].Length - 2)) {
                    $DiscoveryProtocol = ($entry.SubString($HeaderMatch.Groups['type'].Index - 1,$HeaderMatch.Groups['type'].Length - 1)).Trim()
                } else {
                    $DiscoveryProtocol = ($entry.SubString($HeaderMatch.Groups['type'].Index - 1)).Trim()
                }

                switch ($DiscoveryProtocol) {
                    'lldp' {
                        $NewObject.LinkLayerDiscoveryProtocol = $true
                    }
                    'cdp' {
                        $NewObject.CabletronDiscoveryProtocol = $true
                    }
                    default {
                        Write-Warning "DiscoveryProtocol unsupported: $DiscoveryProtocol"
                    }
                }


                $ReturnObject += $NewObject
                continue
            }
        }
    }
    return $ReturnObject
}