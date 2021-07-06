function Get-CiscoSpantreeConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoSpantreeConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup ReturnObject

    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down
    $Ports = Get-CiscoPortName -ConfigArray $LoopArray

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
        $EvalParams.LineNumber = $i

        # stp enable
        $EvalParams.Regex = [regex] '^spanning-tree\ mode\ (.+)'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            Write-Verbose "$VerbosePrefix Spanning Tree enabled"
            if ($null -eq $ReturnObject) {
                $ReturnObject = [SpantreeConfig]::new()
                $ReturnObject.NonAdminEdgePorts = $Ports.Name | Where-Object { $_ -notmatch "Vlan|Null" }
                $ReturnObject.AdminEnabledPorts = $Ports.Name | Where-Object { $_ -notmatch "Vlan|Null" }
                $ReturnObject.SpanGuardEnabled = $false
                $ReturnObject.AutoEdgeEnabled = $true
                $ReturnObject.Mode = $Eval
            }
            $ReturnObject.Enabled = $true
            continue
        }

        # spanning-tree vlan 1-4094 priority 24576
        $EvalParams.Regex = [regex] "^spanning-tree\ vlan\ .+?\ priority\ (\d+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Priority = $Eval
            continue
        }

        # interface config match
        $EvalParams.Regex = [regex] "^interface\ (.+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            Write-Verbose "$VerbosePrefix Checking Interface: $Eval"
            $InInterface = $true
            $InterfaceName = $Eval
            continue
        }

        if ($InInterface) {
            # portfast
            $EvalParams.Regex = [regex] "^\ spanning-tree\ portfast"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.AdminEdgePorts += $InterfaceName
                $ReturnObject.NonAdminEdgePorts = $ReturnObject.NonAdminEdgePorts | Where-Object { $_ -ne $InterfaceName }
                continue
            }

            # End interface
            $EvalParams.Regex = [regex] '^!$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $InInterface = $false
            }
        }
    }
    return $ReturnObject
}