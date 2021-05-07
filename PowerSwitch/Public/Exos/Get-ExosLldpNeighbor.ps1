function Get-ExosLldpNeighbor {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosLldpNeighbor:"

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

        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry

        $EvalParams.Regex = [regex] "#\ show\ lld(p)?\ neigh[bors]+\ detail"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: lldp output started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {

            <#
            [string]$IpAddress
            [string[]]$CapabilitiesSupported
            [string[]]$CapabilitiesEnabled
            #>

            # Local Port
            $EvalParams.Regex = [regex] "^LLDP\ Port\ (.+?)\ detected"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: neighbor found on port $Eval"

                # check to see if Extreme AP info was gathered and apply it to the last neighbor if it was.
                if ($ExtremeApDescription.Serial -or $ExtremeApDescription.Software -or $ExtremeApDescription.Model) {
                    $New.DeviceDescription = $ExtremeApDescription.Model + ', ' + $ExtremeApDescription.Serial + ', ' + $ExtremeApDescription.Software
                }

                $New = [Neighbor]::new()
                $New.LocalPort = $Eval
                $New.LinkLayerDiscoveryProtocol = $true

                # build a better description for Extreme Aps
                $ExtremeApDescription = "" | Select-Object Serial,Software,Model

                $DescriptionKeepGoing = $false

                $ReturnArray += $New
                continue
            }

            # device id
            $EvalParams.Regex = [regex] "^\s+Chassis\ ID\s+:\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $New.DeviceId = $Eval
                continue
            }

            # remote port
            $EvalParams.Regex = [regex] "^\s+Port ID\s+:\ `"(.+?)`""
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $New.RemotePort = $Eval
                continue
            }

            # remote device name
            $EvalParams.Regex = [regex] "^\s+-\ System\ Name:\ `"(.+?)`""
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $New.DeviceName = $Eval
                continue
            }

            # CapabilitiesSupported
            $EvalParams.Regex = [regex] '^\s+-\ System\ Capabilities\ : "(.+?)"'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                foreach ($e in $Eval.Split(',')) {
                    $New.CapabilitiesSupported += $e.Trim()
                }
                continue
            }

            # CapabilitiesEnabled
            $EvalParams.Regex = [regex] '^\s+Enabled\ Capabilities:\ "(.+?)"'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                foreach ($e in $Eval.Split(',')) {
                    $New.CapabilitiesEnabled += $e.Trim()
                }
                continue
            }

            # IpAddress
            $EvalParams.Regex = [regex] "^\s+Management\ Address\s+:\s(.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $New.IpAddress = $Eval
                continue
            }

            # Extreme Ap Serial
            $EvalParams.Regex = [regex] "^\s+-\ MED\ Serial\ Number:\ `"(.+?)`""
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $ExtremeApDescription.Serial = $Eval
                continue
            }

            # Extreme Ap software
            $EvalParams.Regex = [regex] "^\s+-\ MED\ Software\ Revision:\ `"(.+?)`""
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $ExtremeApDescription.Software = $Eval
                continue
            }

            # Extreme Ap model
            $EvalParams.Regex = [regex] "^\s+-\ MED\ Model\ Name:\ `"(.+?)`""
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $ExtremeApDescription.Model = $Eval
                continue
            }

            # Description
            $EvalParams.Regex = [regex] "^\s+-\ System\ Description:\ `"(?<desc>.+?)(?<lastchar>[\\`"])"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New.DeviceDescription = $Eval.Groups['desc'].Value
                if ($Eval.Groups['lastchar'].Value -eq '\') {
                    $DescriptionKeepGoing = $true
                }
                continue
            }

            # Description Continued
            $EvalParams.Regex = [regex] "^\s+(?<desc>.+?)(?<lastchar>[\\`"])"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New.DeviceDescription += $Eval.Groups['desc'].Value
                if ($Eval.Groups['lastchar'].Value -eq '\') {
                    $DescriptionKeepGoing = $true
                } else {
                    $DescriptionKeepGoing = $false
                }
                continue
            }

            # next config section
            $EvalParams.Regex = [regex] "#\ "
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: lldp output complete"
                break fileloop
            }
        }
    }

    return $ReturnArray
}