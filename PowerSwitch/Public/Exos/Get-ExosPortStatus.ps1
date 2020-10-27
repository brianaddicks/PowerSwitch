function Get-ExosPortStatus {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosPortStatus:"

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
    $VlanConfig = Get-ExosVlanConfig -ConfigArray $LoopArray
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

        <# $EvalParams.Regex = [regex] "^=================================================================="
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: Port: status started"
            $KeepGoing = $true
            continue
        } #>

        $EvalParams.Regex = [regex] "^(?<portname>Port\s+)(?<displaystring>Display\s+)(?<vlanname>VLAN\sName\s+)(?<portstate>Port\s+)(?<linkstate>Link\s+)(?<speed>Speed\s+)(?<duplex>Duplex)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: Port: status started"
            $KeepGoing = $true

            $PortStatusRxString = "(?<portname>\d.{" + (($Eval.Groups['portname'].Value).Length - 1) + "})"
            $PortStatusRxString += "(?<displaystring>.{" + ($Eval.Groups['displaystring'].Value).Length + "})"
            $PortStatusRxString += "(?<vlanname>.{" + ($Eval.Groups['vlanname'].Value).Length + "})"
            $PortStatusRxString += "(?<portstate>.{" + ($Eval.Groups['portstate'].Value).Length + "})"
            $PortStatusRxString += "(?<linkstate>.{1," + ($Eval.Groups['linkstate'].Value).Length + "})"
            $PortStatusRxString += "(?<speed>.{" + ($Eval.Groups['speed'].Value).Length + "})?"
            $PortStatusRxString += "(?<duplex>.{1," + ($Eval.Groups['duplex'].Value).Length + "})?"

            $PortStatusRx = [regex] $PortStatusRxString
            continue
        }

        if ($KeepGoing) {
            $EvalParams.Regex = $PortStatusRx
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Name = ($Eval.Groups['portname'].Value).Trim()
                Write-Verbose "$VerbosePrefix port found: $Name"

                $NewPort = [Port]::new($Name)

                $NewPort.Alias = ($Eval.Groups['displaystring'].Value).Trim()
                $NewPort.AdminStatus = ($Eval.Groups['portstate'].Value).Trim()
                $NewPort.OperStatus = ($Eval.Groups['linkstate'].Value).Trim()
                $NewPort.Speed = ($Eval.Groups['speed'].Value).Trim()
                $NewPort.Duplex = ($Eval.Groups['duplex'].Value).Trim()

                $AdminStatusDecoder = New-Object system.collections.hashtable
                $AdminStatusDecoder.D = 'Disabled'
                $AdminStatusDecoder.E = 'Enabled'
                $AdminStatusDecoder.F = 'Disabled by link-flap detection'
                $AdminStatusDecoder.L = 'Disabled due to licensing'

                $NewPort.AdminStatus = $AdminStatusDecoder."$($NewPort.AdminStatus)"

                $OperStatusDecoder = New-Object system.collections.hashtable
                $OperStatusDecoder.A = 'Active'
                $OperStatusDecoder.E = 'Enabled'
                $OperStatusDecoder.R = 'Ready'
                $OperStatusDecoder.NP = 'Port Not Present'
                $OperStatusDecoder.L = 'Loopback'
                $OperStatusDecoder.D = 'ELSM Enabled but not up'
                $OperStatusDecoder.d = 'Ethernet OAM Enabled but not up'

                $NewPort.OperStatus = $OperStatusDecoder."$($NewPort.OperStatus)"

                $ReturnArray += $NewPort
                continue
            }


            # next config section
            $EvalParams.Regex = [regex] '^=+'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval -and $ReturnArray.Count -gt 0) {
                Write-Verbose "$VerbosePrefix $i`: Port: status complete"
                break fileloop
            }
        }
    }

    return $ReturnArray
}