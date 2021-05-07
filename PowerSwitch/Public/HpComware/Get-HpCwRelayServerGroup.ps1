function Get-HpCwRelayServerGroup {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpCwRelayServerGroup:"

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
            continue
        }



        ###########################################################################################
        # Check for the Section

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry
        $EvalParams.Regex = [regex] "^\ +dhcp\ relay\ server-group\ (?<num>1)\ ip\ (?<ip>$IpRx)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: server group found: $Eval"
            $GroupNumber = $Eval.Groups['num'].Value
            $IpAddress = $Eval.Groups['ip'].Value
            $Lookup = $ReturnArray | Where-Object { $_.GroupNumber -eq $GroupNumber}
            if ($Lookup) {
                $Lookup.IpAddress += $IpAddress
            } else {
                $new = "" | Select-Object GroupNumber, IpAddress
                $new.GroupNumber = $GroupNumber
                $new.IpAddress = @($IpAddress)
                $ReturnArray += $new
                $KeepGoing = $true
            }
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry
            $EvalParams.Regex = [regex] "^#"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break fileloop
            }
        }

    }
    return $ReturnArray
}