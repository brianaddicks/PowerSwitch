function Get-HpCwSpantreeConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpCwSpantreeConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    $Ports = Get-EosPortName -ConfigArray $LoopArray

    # Setup ReturnObject

    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down
    $Ports = Get-HpCwPortName -ConfigArray $LoopArray

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
        $EvalParams.ReturnGroupNumber = 1
        $EvalParams.LineNumber = $i

        # stp mode <mode>
        $EvalParams.Regex = [regex] "^\ stp\ mode\ (.+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            if ($null -eq $ReturnObject) {
                $ReturnObject = [SpantreeConfig]::new()
                $ReturnObject.NonAdminEdgePorts = $Ports.Name | Where-Object { $_ -notmatch "Vlan|Null" }
                $ReturnObject.AdminEnabledPorts = $Ports.Name | Where-Object { $_ -notmatch "Vlan|Null" }
                $ReturnObject.SpanGuardEnabled = $false
                $ReturnObject.AutoEdgeEnabled = $true
            }
            $ReturnObject.Mode = $Eval
        }

        # stp enable
        $EvalParams.Regex = [regex] "^\ stp\ (enable)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            if ($null -eq $ReturnObject) {
                $ReturnObject = [SpantreeConfig]::new()
                $ReturnObject.NonAdminEdgePorts = $Ports.Name | Where-Object { $_ -notmatch "Vlan|Null" }
                $ReturnObject.AdminEnabledPorts = $Ports.Name | Where-Object { $_ -notmatch "Vlan|Null" }
                $ReturnObject.SpanGuardEnabled = $false
                $ReturnObject.AutoEdgeEnabled = $true
            }
            $ReturnObject.Enabled = $true
        }

        # interface config match
        $EvalParams.Regex = [regex] "^interface\ (.+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix Checking Interface: $Eval"
            $InInterface = $true
            $InterfaceName = $Eval
        }

        if ($InInterface) {
            # interface config match
            $EvalParams.Regex = [regex] "^ stp\ edged-port\ (enable)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.AdminEdgePorts += $InterfaceName
                $ReturnObject.NonAdminEdgePorts = $ReturnObject.NonAdminEdgePorts | Where-Object { $_ -ne $InterfaceName }
                $InInterface = $true
                $InterfaceName = $Eval
            }

            # End interface
            $EvalParams.Regex = [regex] '^#$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $InInterface = $false
            }
        }


    }
    return $ReturnObject
}