function Get-ExosPortConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosPortConfig:"

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
    $ReturnArray = Get-ExosPortStatus -ConfigArray $LoopArray

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down

    # The following Rx will be ignored
    $IgnoreRx = @(
        'configure\ vlan'
        'enable\ ipforwarding'
        'create\ vlan'
        'enable\ loopback-mode'
    )

    # Add Vlan Config
    $VlanConfig = Get-ExosVlanConfig -ConfigArray $LoopArray
    foreach ($port in $ReturnArray) {
        foreach ($vlan in $VlanConfig) {
            if ($vlan.UntaggedPorts -contains $port.Name) {
                $port.UntaggedVlan += $vlan.Id
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

        $EvalParams.Regex = [regex] "^#\ Module\ vlan\ configuration"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: vlan: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # enable jumbo-frame ports <port>
            $EvalParams.Regex = [regex] '^enable\ jumbo-frame\ ports\ (.+)'
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

            # configure ports <port> display-string <alias>
            $EvalParams.Regex = [regex] '^configure\ ports\ (?<port>.+?)\ display-string\ (?<display>.+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = CheckForExistingPort $Eval.Groups['port'].Value
                if ($New) {
                    $New.Alias = $Eval.Groups['display'].Value
                } else {
                    $New = [Port]::new($Eval.Groups['port'].Value)
                    $New.Alias = $Eval.Groups['display'].Value
                    $ReturnArray += $New
                }
                continue
            }

            # disable port <port>
            $EvalParams.Regex = [regex] '^disable port (.+)'
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

            # configure ports <port> auto off speed 10000 duplex full
            $EvalParams.Regex = [regex] '^configure\ ports\ (?<port>.+?)\ auto\ (?<negotiation>.+?)\ speed\ (?<speed>\d+)(\ duplex\ (?<duplex>.+))?'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $PortName = $Eval.Groups['port'].Value
                $New = CheckForExistingPort $PortName
                if ($New) {
                    if ($Eval.Groups['negotiation'].Value -eq 'off') {
                        $New.NoNegotiate = $true
                    }
                    $New.Speed = $Eval.Groups['speed'].Value
                    if ($Eval.Groups['duplex'].Success) {
                        $New.Duplex = $Eval.Groups['duplex'].Value
                    }
                } else {
                    $New = [Port]::new($PortName)
                    $New.Aggregate = $Eval.Groups['negotiation'].Value
                    if ($Eval.Groups['negotiation'].Value -eq 'off') {
                        $New.NoNegotiate = $true
                    }
                    $New.Speed = $Eval.Groups['speed'].Value
                    if ($Eval.Groups['duplex'].Success) {
                        $New.Duplex = $Eval.Groups['duplex'].Value
                    }
                    $ReturnArray += $New
                }
                continue
            }

            # enable sharing <master-port> grouping <ports> algorithm <algorithm> lacp
            $EvalParams.Regex = [regex] '^enable\ sharing\ (?<masterport>.+?)\ grouping\ (?<ports>.+?)\ algorithm\ (?<alg>address-based\ [^\ ]+)(?<lacp>\ lacp)?'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $MemberPorts = Resolve-PortString -PortString $Eval.Groups['ports'].Value -SwitchType Exos
                $global:test2 = $MemberPorts
                foreach ($port in $MemberPorts) {
                    $New = CheckForExistingPort $port
                    if ($New) {
                        $New.Aggregate = $Eval.Groups['masterport'].Value
                        $New.AggregateAlgorithm = $Eval.Groups['alg'].Value
                        if ($Eval.Groups['lacp'].Success) {
                            $New.LacpEnabled = $true
                        }
                    } else {
                        $New = [Port]::new($port)
                        $New.Aggregate = $Eval.Groups['masterport'].Value
                        $New.AggregateAlgorithm = $Eval.Groups['alg'].Value
                        if ($Eval.Groups['lacp'].Success) {
                            $New.LacpEnabled = $true
                        }
                        $ReturnArray += $New
                    }
                }
                continue
            }

            foreach ($Rx in $IgnoreRx) {
                $EvalParams.Regex = [regex] $Rx
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    continue fileloop
                }
            }

            Write-Verbose "$VerbosePrefix $i`: $entry"

            # next config section
            $EvalParams.Regex = [regex] "^(#)\ "
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break fileloop
            }
        }
    }
    return $ReturnArray
}