function Get-EosPortConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosPortConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
    $ReturnArray = Get-EosPortStatus -ConfigArray $LoopArray
    $LacpMappings = @()

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down

    # The following Rx will be ignored
    $IgnoreRx = @(
    )

    # Add Vlan Config
    $VlanConfig = Get-EosVlanConfig -ConfigArray $LoopArray
    foreach ($port in $ReturnArray) {
        foreach ($vlan in $VlanConfig) {
            if ($vlan.UntaggedPorts -contains $port.Name) {
                $port.UntaggedVlan = $vlan.Id
            }
            if ($vlan.TaggedPorts -contains $port.Name) {
                $port.TaggedVlan += $vlan.Id
            }
        }
    }

    function CheckForExistingPort ([string]$Port) {
        $ExistingPort = $ReturnArray | Where-Object { $_.Name -eq $Port }
        if ($ExistingPort) {
            #Write-Verbose "$VerbosePrefix port exists: $Port"
            return $ExistingPort
        } else {
            #Write-Verbose "$VerbosePrefix new port needed: $Port"
            return $false
        }
    }

    :fileloop foreach ($entry in $LoopArray) {
        $i++

        # Write progress bar, we're only updating every 1000ms, if we do it every line it takes forever

        if ($StopWatch.Elapsed.TotalMilliseconds -ge 1000) {
            $PercentComplete = [math]::truncate($i / $TotalLines * 100)
            Write-Progress -Activity "$VerbosePrefix Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
            $StopWatch.Reset()
            $StopWatch.Start()
        }

        if ($entry -eq "") { continue }

        ###########################################################################################
        # Check for the Section

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry

        $EvalParams.Regex = [regex] '^begin$'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: show conf started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            Write-Verbose "$VerbosePrefix $i`: $entry"

            # end "show conf"
            $EvalParams.Regex = [regex] '^end$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break fileloop
            }

            # ignored regexes
            foreach ($Rx in $IgnoreRx) {
                $EvalParams.Regex = [regex] $Rx
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    continue fileloop
                }
            }

            # set port jumbo enable <port>
            $EvalParams.Regex = [regex] '^set\ port\ jumbo\ enable\ (.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $New = CheckForExistingPort $Eval
                if ($New) {
                    $New.JumboEnabled = $true
                } else {
                    $New = [Port]::new($Eval)
                    $New.JumboEnabled = $true
                    $ReturnArray += $New
                }
                continue
            }

            # set port alias <port> <alias>
            $EvalParams.Regex = [regex] '^set\ port\ alias\ (?<port>.+?)\ (?<alias>.+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = CheckForExistingPort $Eval.Groups['port'].Value
                if ($New) {
                    $New.Alias = $Eval.Groups['alias'].Value
                } else {
                    $New = [Port]::new($Eval.Groups['port'].Value)
                    $New.Alias = $Eval.Groups['alias'].Value
                    $ReturnArray += $New
                }
                continue
            }

            # set port disable <port>
            $EvalParams.Regex = [regex] '^set\ port\ disable\ (?<port>.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $New = CheckForExistingPort $Eval
                if ($New) {
                    $New.AdminStatus = 'disabled'
                } else {
                    $New = [Port]::new($Eval)
                    $New.AdminStatus = 'disabled'
                    $ReturnArray += $New
                }
                continue
            }

            # set port speed <port> <speed>
            $EvalParams.Regex = [regex] '^set\ port\ speed\ (?<port>.+?)\ (?<speed>.+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $PortName = $Eval.Groups['port'].Value
                $New = CheckForExistingPort $PortName
                if ($New) {
                    $New.Speed = $Eval.Groups['speed'].Value
                } else {
                    $New = [Port]::new($PortName)
                    $New.Speed = $Eval.Groups['speed'].Value
                    $ReturnArray += $New
                }
                continue
            }

            # set port duplex <port> <duplex>
            $EvalParams.Regex = [regex] '^set\ port\ speed\ (?<port>.+?)\ (?<duplex>.+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $PortName = $Eval.Groups['port'].Value
                $New = CheckForExistingPort $PortName
                if ($New) {
                    $New.Speed = $Eval.Groups['duplex'].Value
                } else {
                    $New = [Port]::new($PortName)
                    $New.Speed = $Eval.Groups['duplex'].Value
                    $ReturnArray += $New
                }
                continue
            }

            # set port negotiation <port> disable
            $EvalParams.Regex = [regex] '^set\ port\ negotiation\ (?<port>.+?)\ disable'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $PortName = $Eval.Groups['port'].Value
                $New = CheckForExistingPort $PortName
                if ($New) {
                    $New.NoNegotiate = $true
                } else {
                    $New = [Port]::new($PortName)
                    $New.NoNegotiate = $true
                    $ReturnArray += $New
                }
                continue
            }

            # set port lacp port <port> enable
            $EvalParams.Regex = [regex] '^set\ port\ lacp\ port\ (?<port>.+?)\ enable'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $PortName = $Eval.Groups['port'].Value
                $New = CheckForExistingPort $PortName
                if ($New) {
                    $New.LacpEnabled = $true
                } else {
                    $New = [Port]::new($PortName)
                    $New.LacpEnabled = $true
                    $ReturnArray += $New
                }
                continue
            }

            # set lacp aadminkey lag.0.1 1
            $EvalParams.Regex = [regex] '^set\ lacp\ aadminkey\ (?<port>.+?)\ (?<aadminkey>\d+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix lag found"
                $NewLag = "" | Select-Object LagPort,AadminKey
                $NewLag.LagPort = $Eval.Groups['port'].Value
                $NewLag.AadminKey = $Eval.Groups['aadminkey'].Value
                $LacpMappings += $NewLag
                continue
            }

            # set port lacp port <port> aadminkey <key>
            $EvalParams.Regex = [regex] '^set\ port\ lacp\ port\ (?<port>.+?)\ aadminkey\ (?<key>\d+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $PortName = $Eval.Groups['port'].Value
                $AadminKey = $Eval.Groups['key'].Value
                $LagLookup = $LacpMappings | Where-Object { $_.AadminKey -eq $AadminKey }
                $New = CheckForExistingPort $PortName
                if ($New) {
                    $New.Aggregate = $LagLookup.LagPort
                } else {
                    $New = [Port]::new($PortName)
                    $New.Aggregate = $LagLookup.LagPort
                    $ReturnArray += $New
                }
                continue
            }
        }
    }
    $global:lacp = $LacpMappings
    return $ReturnArray | Where-Object { $_.Name -notmatch '(vlan|lo|tbp|host|com)\.' }
}