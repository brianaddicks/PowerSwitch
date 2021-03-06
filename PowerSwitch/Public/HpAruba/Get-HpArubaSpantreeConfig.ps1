function Get-HpArubaSpantreeConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpArubaSpantreeConfig:"

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
    $Ports = Get-HpArubaPortName -ConfigArray $LoopArray

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
        $EvalParams.Regex = [regex] '^spanning-tree$'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix Spanning Tree enabled"
            if ($null -eq $ReturnObject) {
                $ReturnObject = [SpantreeConfig]::new()
                $ReturnObject.NonAdminEdgePorts = $Ports.Name | Where-Object { $_ -notmatch "Vlan|Null" }
                $ReturnObject.AdminEnabledPorts = $Ports.Name | Where-Object { $_ -notmatch "Vlan|Null" }
                $ReturnObject.SpanGuardEnabled = $false
                $ReturnObject.AutoEdgeEnabled = $true
            }
            $ReturnObject.Enabled = $true
            continue
        }

        # spanning-tree priority <priority>
        $EvalParams.Regex = [regex] "^spanning-tree\ priority\ (.+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            Write-Verbose "$VerbosePrefix priority found: $Eval"
            $ReturnObject.Priority = [int]$Eval * 4096
            continue
        }

    }
    return $ReturnObject
}