function Get-CiscoVlanConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $false)]
        [switch]$NoPortConfig
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

    if (-not $NoPortConfig) {
        $PortConfig = Get-CiscoPortConfig -ConfigArray $LoopArray
    }
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
            Write-Progress -Activity "$VerbosePrefix Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
            $StopWatch.Reset()
            $StopWatch.Start()
        }

        if ($entry -eq "") {
            if ($KeepGoing) {
                $ShowVlanComplete = $true
                $OutputStarted = $false
                $KeepGoing = $false
            }
            continue
        }

        ###########################################################################################
        # Check for the Section

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry

        $Regex = [regex] '\w+\#show\ vlan'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: 'show vlan' found"
            if (-not $ShowVlanComplete) {
                $OutputStarted = $true
            }
            continue
        }

        if ($OutputStarted) {
            $Regex = [regex] '(?x)
            ^(?<id>VLAN\s+?)
            (?<name>Name\s+?)
            (?<status>Status\s+?)
            (?<ports>Ports)'
            $Eval = Get-RegexMatch $Regex $entry
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: header found: $($Eval.Value)"
                $KeepGoing = $true

                $PortLength = ($Eval.Groups['id'].Value).Length
                $NameLength = ($Eval.Groups['name'].Value).Length
                $StatusLength = ($Eval.Groups['status'].Value).Length
                $PortsLength = ($Eval.Groups['ports'].Value).Length

                $CalculatedRxString = "(?<id>\d+)\s+?"
                $CalculatedRxString += "(?<name>.{$NameLength})"
                $CalculatedRxString += "(?<status>.+)"
                #$CalculatedRxString += "(?<ports>.{$PortsLength})"
                continue
            }
        }

        if ($KeepGoing) {
            # vlan id, name, status
            $EvalParams.Regex = [regex] $CalculatedRxString
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $VlanId = [int]($Eval.Groups['id'].Value)
                Write-Verbose "$VerbosePrefix $i`: vlan found $VlanId"
                $new = [Vlan]::new($VlanId)
                $new.Name = ($Eval.Groups['name'].Value).Trim()

                $ReturnArray += $new
                continue
            }
        }

        # vlan 1111
        $EvalParams.Regex = [regex] '^vlan\s(\d+)'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $VlanId = [int]$Eval
            Write-Verbose "$VerbosePrefix $i`: config vlan found $VlanId"
            $VlanLookup = $ReturnArray | Where-Object { $_.Id -eq $VlanId }
            if (-not $VlanLookup) {
                $new = [Vlan]::new($VlanId)

                $VlanFromConfig = $true
                $ReturnArray += $new
            }
            continue
        }

        if ($VlanFromConfig) {
            # name <name>
            $EvalParams.Regex = [regex] '^\sname\s(.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval -and $new) {
                $new.Name = $Eval
                $VlanFromConfig = $false
                continue
            }
        }
    }

    $DefaultVlanLookup = $ReturnArray | Where-Object { $_.Id -eq 1 }
    if (-not $DefaultVlanLookup) {
        $new = [Vlan]::new(1)
        $new.Name = 'default'
        $ReturnArray += $new
    }

    if (-not $NoPortConfig) {
        foreach ($port in $PortConfig) {
            $UntaggedVlanLookup = $ReturnArray | Where-Object { $_.Id -eq $port.UntaggedVlan }
            $UntaggedVlanLookup.UntaggedPorts += $port.Name
            $global:test = $port

            if ($port.VoiceVlan -gt 0) {
                $VoiceVlanLookup = $ReturnArray | Where-Object { $_.Id -eq $port.VoiceVlan }
                $VoiceVlanLookup.TaggedPorts += $port.Name
            }

            if ($port.TaggedVlan.Count -gt 1) {
                $TaggedVlanLookup = $ReturnArray | Where-Object { $port.TaggedVlan -contains $_.Id }
                foreach ($vlan in $TaggedVlanLookup) {
                    $vlan.TaggedPorts += $port.Name
                }
            }

            if ($port.TaggedVlan.Count -eq 0 -and $port.Mode -eq 'trunk') {
                foreach ($vlan in $ReturnArray) {
                    $vlan.TaggedPorts += $port.Name
                }
            }
        }
    }

    return $ReturnArray
}