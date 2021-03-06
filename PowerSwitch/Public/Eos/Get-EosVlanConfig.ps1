function Get-EosVlanConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $True)]
        [array]$Ports
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosVlanConfig:"

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
    $ReturnArray += [Vlan]::new(1)
    $ReturnArray[0].Name = "Default Vlan"

    if ($Ports) {
        $ReturnArray[0].UntaggedPorts = ($Ports | Where-Object { $_.type -ne "other" -and $_.Name -notmatch 'Vlan' }).Name
    }

    $global:test = $ReturnArray

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

        if ($entry -eq "") { continue }

        ###########################################################################################
        # Check for the Section

        $Regex = [regex] '^#(\ )?vlan$'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: vlan: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry
            $EvalParams.ReturnGroupNumber = 1

            # vlan create
            $EvalParams.Regex = [regex] "^set\ vlan\ create\ (.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: vlan: create"
                $ResolvedVlans = Resolve-VlanString -VlanString $Eval -SwitchType 'Eos'
                foreach ($r in $ResolvedVlans) {
                    $ReturnArray += [Vlan]::new([int]$r)
                }
            }

            # vlan name
            $EvalParams.Remove('ReturnGroupNumber')
            $EvalParams.Regex = [regex] 'set\ vlan\ name\ (?<id>\d+)\ "?(?<name>[^"]+)"?'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $VlanId = $Eval.Groups['id'].Value
                $VlanName = $Eval.Groups['name'].Value
                Write-Verbose "$VerbosePrefix $i`: vlan: id $VlanId = name $VlanName"
                $Lookup = $ReturnArray | Where-Object { $_.Id -eq $VlanId }
                if ($Lookup) {
                    $Lookup.Name = $VlanName
                } else {
                    Throw "$VerbosePrefix $i`: vlan: $VlanId not found in ReturnArray"
                }
            }

            # clear vlan egress 1
            $EvalParams.Regex = [regex] "clear\ vlan\ egress\ 1\ (?<ports>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                <# Write-Verbose "$VerbosePrefix $i`: vlan: clear egress 1"
                $ThesePorts = $Eval.Groups['ports'].Value
                $ThesePorts = Resolve-PortString -PortString $ThesePorts -SwitchType 'Eos'
                $VlanLookup = $ReturnArray | Where-Object { $_.Id -eq 1 }
                foreach ($port in $ThesePorts) {
                    $VlanLookup.UntaggedPorts = $Vlan.UntaggedPorts | Where-Object { $_ -ne $port }
                } #>

                <# Write-Verbose "$VerbosePrefix $i`: vlan: $($LookupPorts.Count) ports to be cleared"
                $LookupPorts = $Ports | Where-Object { $ThesePorts -contains $_.Name }
                Write-Verbose "$VerbosePrefix $i`: vlan: $($LookupPorts.Count) ports"
                foreach ($p in $LookupPorts) {
                    if ($p.UntaggedVlan -eq 1) {
                        $p.UntaggedVlan = $null
                    }
                    if ($p.TaggedVlan -contains 1) {
                        $p.TaggedVlan = $P.TaggedVlan | Where-Object { $_ -ne 1 }
                    }
                } #>
            }

            # vlan egress
            $EvalParams.Regex = [regex] "^set\ vlan\ egress\ (?<id>\d+)\ (?<ports>.+?)\ (?<tagging>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $VlanId = $Eval.Groups['id'].Value
                $ThesePorts = $Eval.Groups['ports'].Value
                $Tagging = $Eval.Groups['tagging'].Value

                Write-Verbose "$VerbosePrefix $i`: vlan: $VlanId`: ports $ThesePorts, $Tagging"
                $Lookup = $ReturnArray | Where-Object { $_.Id -eq $VlanId }
                if ($Lookup) {
                    switch ($Tagging) {
                        'tagged' {
                            $Lookup.TaggedPorts += Resolve-PortString -PortString $ThesePorts -SwitchType 'Eos'
                        }
                        'untagged' {
                            $Lookup.UntaggedPorts += Resolve-PortString -PortString $ThesePorts -SwitchType 'Eos'
                        }
                    }
                } else {
                    Throw "$VerbosePrefix $i`: vlan: $VlanId not found in ReturnArray"
                }
            }

            $Regex = [regex] '^#'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                break
            }
        }
    }
    return $ReturnArray
}