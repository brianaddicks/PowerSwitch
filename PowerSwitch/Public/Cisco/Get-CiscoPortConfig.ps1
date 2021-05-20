function Get-CiscoPortConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoPortConfig:"
    Write-Verbose 'RUNNING'

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
    $Slot = 0

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down

    Write-Verbose "RUNNING $($LoopArray.Count)"

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
        $EvalParams.Regex = [regex] "^interface\ (.+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: interface found: $Eval"
            if ($Eval -match 'Vlan|Loopback') {
                continue
            }
            $new = [Port]::new($Eval)
            $new.Mode = 'access'
            $ReturnArray += $new
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # switchport mode
            $EvalParams.Regex = [regex] "^\ +switchport\ mode\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.Mode = $Eval
                continue
            }

            # switchport trunk allowed vlan
            $EvalParams.Regex = [regex] "^\ +switchport\ trunk\ allowed\ vlan\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.TaggedVlan = $Eval.Split(',')
                continue
            }

            # switchport trunk native vlan
            $EvalParams.Regex = [regex] "^\ +switchport\ trunk\ native\ vlan\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.TaggedVlan = $new.TaggedVlans | Where-Object { $_ -ne $Eval }
                $new.UntaggedVlan = $Eval
                continue
            }

            # switchport access vlan
            $EvalParams.Regex = [regex] "^\ +switchport\ access\ vlan\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.UntaggedVlan = $Eval
                continue
            }

            # switchport voice vlan
            $EvalParams.Regex = [regex] "^\ +switchport\ voice\ vlan\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.VoiceVlan = $Eval
                continue
            }

            # description
            $EvalParams.Regex = [regex] "^\ +description\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.Alias = $Eval
                continue
            }

            # channel-group
            $EvalParams.Regex = [regex] "^\ +channel-group\ (\d+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.Aggregate = $Eval
                continue
            }

            # spanning-tree bpduguard enable
            $EvalParams.Regex = [regex] "^\ +spanning-tree bpduguard enable"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.BpduGuard = $true
                continue
            }

            # spanning-tree mode
            $EvalParams.Regex = [regex] "^\ +spanning-tree (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.StpMode = $Eval
                continue
            }

            # ip dhcp snooping trust
            $EvalParams.Regex = [regex] "^\ +ip\ dhcp\ snooping\ trust"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.DhcpSnoopingTrust = $true
                continue
            }

            # shutdown
            $EvalParams.Regex = [regex] "^\ +shutdown"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.AdminStatus = "False"
                continue
            }

            # end of interface
            $EvalParams.Regex = [regex] "^!"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $KeepGoing = $false
                continue
            }
        }
    }
    return $ReturnArray
}