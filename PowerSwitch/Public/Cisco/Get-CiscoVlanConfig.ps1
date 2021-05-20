function Get-CiscoVlanConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoVlanConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    $PortConfig = Get-CiscoPortConfig -ConfigArray $LoopArray
    # Setup return Array
    $ReturnArray = @()

    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
    $Slot = 0

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
            if ($InModule) {
                break
            }
            continue
        }

        ###########################################################################################
        # Check for the Section

        $Regex = [regex] '\w+\#show\ vlan'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: 'show vlan' found"
            $SlotStart = $true
            continue
        }

        if ($SlotStart) {
            $Regex = [regex] '^(-+\ +)+-+$'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                Write-Verbose "$VerbosePrefix $i`: vlan output starting"
                $InModule = $true
                continue
            }
        }

        if ($InModule) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # vlan id, name, status
            $EvalParams.Regex = [regex] "(?<id>\d+)\s+(?<name>[^\ ]+?)\s+(?<status>[^\ ]+?)\s+"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Slot++
                $VlanId = [int]($Eval.Groups['id'].Value)
                Write-Verbose "$VerbosePrefix $i`: vlan found $VlanId"
                $new = [Vlan]::new($VlanId)
                $new.Name = $Eval.Groups['name'].Value

                $ReturnArray += $new
            }
        }
    }

    foreach ($port in $PortConfig) {
        $UntaggedVlanLookup = $ReturnArray | Where-Object { $_.Id -eq $port.UntaggedVlan }
        $UntaggedVlanLookup.UntaggedPorts += $port.Name

        if ($port.VoiceVlan -gt 0) {
            $VoiceVlanLookup = $ReturnArray | Where-Object { $_.Id -eq $port.VoiceVlan }
            $VoiceVlanLookup.TaggedPorts += $port.Name
        }

        if ($port.TaggedVlan.Count -gt 1) {
            $TaggedVlanLookup = $ReturnArray | Where-Object { $_.Id -eq $port.TaggedVlan }
            $TaggedVlanLookup.TaggedPorts += $port.Name
        }

        if ($port.TaggedVlan.Count -eq 0 -and $port.Mode -eq 'trunk') {
            foreach ($vlan in $ReturnArray) {
                $vlan.TaggedPorts += $port.Name
            }
        }
    }

    return $ReturnArray
}