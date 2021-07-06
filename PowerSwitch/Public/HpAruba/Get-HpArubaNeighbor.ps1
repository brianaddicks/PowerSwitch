function Get-HpArubaNeighbor {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpArubaNeighbor:"

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

    $HostConfig = Get-HpArubaHostConfig -ConfigArray $LoopArray -ErrorAction SilentlyContinue

    #$DhcpRelays = Get-HpArubaRelayServerGroup -ConfigArray $LoopArray

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
            if ($InModule) {
                break
            }
            continue
        }

        ###########################################################################################
        # Check for the Section

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry
        $EvalParams.Regex = [regex] 'show\slldp\sinfo\sremote-device\sdetail'
        $EvalParams.LineNumber = $i

        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: neighbor command found"
            $new = [Neighbor]::new()
            $new.LinkLayerDiscoveryProtocol = $true
            $ReturnArray += $new
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry
            $EvalParams.LineNumber = $i

            # new entry seperator
            $EvalParams.Regex = [regex] '^-----+$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: new entry found"
                $new = [Neighbor]::new()
                $new.LinkLayerDiscoveryProtocol = $true
                $ReturnArray += $new
                $KeepGoing = $true
                continue
            }

            #   Local Port   : PORT
            $EvalParams.Regex = [regex] '^\s+Local\sPort\s+:\s+(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.LocalPort = $Eval
                continue
            }

            #   SysName      : NAME
            $EvalParams.Regex = [regex] '^\s+SysName\s+:\s+(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.DeviceName = $Eval
                continue
            }

            #   ChassisId      : ID
            $EvalParams.Regex = [regex] '^\s+ChassisId\s+:\s+(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.DeviceId = $Eval
                continue
            }

            #   PortDescr      : PORT
            $EvalParams.Regex = [regex] '^\s+PortDescr\s+:\s+(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.RemotePort = $Eval
                continue
            }

            #   Address      : IPADDRESS
            $EvalParams.Regex = [regex] '^\s+Address\s+:\s+(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.IpAddress = $Eval
                continue
            }

            #   System Descr      : SYSTEMDESCRIPTION
            $EvalParams.Regex = [regex] '^\s+System\sDescr\s+:\s+(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.DeviceDescription = $Eval
                continue
            }

            #   System Capabilities Supported      : CAPABILITIES
            $EvalParams.Regex = [regex] '^\s+System\sCapabilities\sSupported\s+:\s+(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $Split = $Eval.Split(',')
                foreach ($cap in $Split) {
                    $new.CapabilitiesSupported += $cap.Trim()
                }
                continue
            }

            #   System Capabilities Enabled      : CAPABILITIES
            $EvalParams.Regex = [regex] '^\s+System\sCapabilities\sEnabled\s+:\s+(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $Split = $Eval.Split(',')
                foreach ($cap in $Split) {
                    $new.CapabilitiesEnabled += $cap.Trim()
                }
                continue
            }

            # end of neighbor output
            $EvalParams.Regex = [regex] "^$($HostConfig.Prompt)#"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $KeepGoing = $false
                Write-Verbose "$VerbosePrefix $i`: neighbor output complete"
                break
            }
        }
    }
    return $ReturnArray
}