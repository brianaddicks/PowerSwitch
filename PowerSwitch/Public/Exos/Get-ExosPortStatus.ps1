function Get-ExosPortStatus {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosVlanConfig:"

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
    $VlanConfig= Get-ExosVlanConfig -ConfigArray $LoopArray
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

        $EvalParams.Regex = [regex] "^=================================================================="
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: Port: status started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # create vlan "(vlan-name)"
            $EvalParams.Regex = [regex] "^(?<port>.{1,6})(?<description>.{1,16})(?<vlan>.{1,20})(?<portstate>.{1,6})(?<linkstate>.{1,6})(?<speed>.{1,6})(?<duplex>.{1,6})"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Port = ($Eval.Groups['port'].Value).Trim()
                $Description = ($Eval.Groups['description'].Value).Trim()
                $Vlan = ($Eval.Groups['vlan'].Value).Trim()
                $PortState = ($Eval.Groups['portstate'].Value).Trim()
                $LinkState = ($Eval.Groups['linkstate'].Value).Trim()
                $Speed = ($Eval.Groups['speed'].Value).Trim()
                $Duplex = ($Eval.Groups['duplex'].Value).Trim()
                #Write-Host "$Port $Description $Vlan $PortState $LinkState $Speed $Duplex"
                $NewPort = [Port]::new($Port)
                $NewPort.Alias = $Description
                if ($PortState -eq "D" -or $PortState -eq "F") {
                    $NewPort.AdminStatus = "Disabled"
                }else{
                    $NewPort.AdminStatus = "Enabled"
                }
                $VlanConfigUntaggedPorts = $VlanConfig | Where-Object { $_.UntaggedPorts -contains $Port }
                    $NewPort.NativeVlan = $VlanConfigUntaggedPorts.Id
                    $NewPort.UntaggedVlan = $VlanConfigUntaggedPorts.Id   
                $VlanConfigTaggedPorts = $VlanConfig | Where-Object { $_.TaggedPorts -contains $Port }
                $NewPort.VoiceVlan = $null
                $NewPort.TaggedVlan = $VlanConfigTaggedPorts.Id
                if ($LinkState -eq "A") {
                    $NewPort.OperStatus = "Active"
                }elseif ($LinkState -eq "R") {
                    $NewPort.OperStatus = "Ready"
                }elseif ($LinkState -eq "NP") {
                    $NewPort.OperStatus = "Port Not Present"
                }elseif ($LinkState -eq "L") {
                    $NewPort.OperStatus = "Loopback"
                }elseif ($LinkState -eq "D") {
                    $NewPort.OperStatus = "ELSM Enabled but not up"
                }elseif ($LinkState -eq "d") {
                    $NewPort.OperStatus = "Ethernet OAM Enabled but not up"
                }
                $NewPort.Speed = $Speed
                $NewPort.Duplex = $Duplex 
                $ReturnArray += $NewPort
                continue
            }


            # next config section
            $EvalParams.Regex = [regex] '^(==================================================================)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break fileloop
            }
        }
    }

    return $ReturnArray
}