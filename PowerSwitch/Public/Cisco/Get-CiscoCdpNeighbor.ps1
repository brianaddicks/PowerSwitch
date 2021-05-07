function Get-CiscoCdpNeighbor {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoCdpNeighbor:"

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

        $Regex = [regex] 'show\ cdp\ neighbors\ detail'
        $Eval = Get-RegexMatch $Regex $entry
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: cdp neighbor: output started"
            $InSection = $true

            continue
        }

        if ($InSection) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # Device ID
            $EvalParams.Regex = [regex] 'Device\sID:\s(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $NewObject = [Neighbor]::new()
                $NewObject.CiscoDiscoveryProtocol = $true
                $NewObject.DeviceId = $Eval

                $ReturnArray += $NewObject
            }

            if ($NewObject) {
                # Interfaces
                $EvalParams.Regex = [regex] 'Interface:\s(?<localport>.+?),\s+Port\sID\s\(outgoing\sport\):\s+(?<remoteport>.+)'
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    $NewObject.LocalPort = $Eval.Groups[1].Value
                    $NewObject.RemotePort = $Eval.Groups[2].Value
                }

                # Platform and Capabilities
                $EvalParams.Regex = [regex] 'Platform:\s(?<platform>.+),\s+Capabilities:\s(?<capabilities>.+)'
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    $NewObject.DeviceDescription = $Eval.Groups['platform'].Value
                    $NewObject.CapabilitiesSupported = ($Eval.Groups['capabilities'].Value).Trim().Split()
                }

                ##################################
                # Simple Properties
                $EvalParams.VariableToUpdate = ([REF]$NewObject)
                $EvalParams.ReturnGroupNumber = 1
                $EvalParams.LoopName = 'fileloop'

                # IP address: 10.192.0.1
                $EvalParams.ObjectProperty = "IpAddress"
                $EvalParams.Regex = [regex] '^\s+IP\saddress:\s(.+)'
                $Eval = Get-RegexMatch @EvalParams
            }

<#             if ($entry -notmatch "^\w+\.\d+\.\d+") {
                break
            } #>
        }
    }
    if ($ReturnArray.Count -eq 0) {
        Throw "$VerbosePrefix No CDP Neighbors found, requires output from 'show cdp neighbors detail'"
    } else {
        return $ReturnArray
    }
}


<#
[string]$DeviceName
[string]$DeviceDescription

[string[]]$CapabilitiesSupported
[string[]]$CapabilitiesEnabled
#>