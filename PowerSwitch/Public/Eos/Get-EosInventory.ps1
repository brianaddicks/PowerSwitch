function Get-EosInventory {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosInventory:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $ReturnObject = @()

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
            if ($InSlot) {
                Write-Verbose "$VerbosePrefix $i`: slot complete"
                $InSlot = $false
            }
            continue
        }

        ###########################################################################################
        # Check for the Section

        $Regex = [regex] '->show\ system\ hardware'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: system hardware output started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {

            # Look for section stop, this should match a new prompt string and nothing else
            $Regex = [regex] '->'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                Write-Verbose "$VerbosePrefix $i`: system hardware output complete"
                break
            }

            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry
            $EvalParams.ReturnGroupNumber = 1

            #region s-series
            #################################################################################

            # chassis type
            $EvalParams.Regex = [regex] "^\s+Chassis\sType:\s+(.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: chassis found"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
                $new.Slot = 'Chassis'
                $new.Model = $Eval
                $ReturnObject += $new
                continue
            }

            # chassis type
            $EvalParams.Regex = [regex] "^\s+Chassis\sSerial\sNumber:\s+(.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: chassis found"
                $new.Serial = $Eval
                continue
            }

            #region s4psu
            #################################################################################

            # power supplies
            $Regex = [regex] "^\s+Chassis\sPower\sSupply\s(?<slot>\d+):\s+(?<status>.+)"
            $Eval = Get-RegexMatch -StringToEval $entry -Regex $Regex
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: psu found $($Eval.Groups['slot'].Value)"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
                $new.Slot = 'PSU' + $Eval.Groups['slot'].Value
                $new.Status = $Eval.Groups['status'].Value
                $new.Model = 'unknown-psu'
                $ReturnObject += $new

                $InPsu = $true
                continue
            }

            if ($InPsu) {
                # psu type
                $EvalParams.Regex = [regex] "^\s+Type\s=\s(.+)"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    Write-Verbose "$VerbosePrefix $i`: psu model found"
                    $new.Model = $Eval
                    $InPsu = $false
                    continue
                }
            }

            #################################################################################
            #region s4psu

            #region slot
            #################################################################################

            # slot start
            $EvalParams.Regex = [regex] "^\s+SLOT\s(\d+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: slot started: $Eval"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
                $new.Slot = $Eval
                $ReturnObject += $new

                $CurrentSlot = $Eval
                $InModule = $false
                $InSlot = $true
                $InPsu = $false
                continue
            }

            if ($InSlot) {
                # model
                $EvalParams.Regex = [regex] "^\s+Model:\s+(.+)"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    if (-not $new.Model) {
                        Write-Verbose "$VerbosePrefix $i`: model found: $Eval"
                        $new.Model = $Eval
                    }
                    continue
                }

                # serial
                $EvalParams.Regex = [regex] "^\s+Serial\sNumber:\s+(.+)"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    $new.Serial = $Eval
                    continue
                }

                # firmware
                $EvalParams.Regex = [regex] "^\s+Firmware\sVersion:\s+(.+)"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    $new.Firmware = $Eval
                    continue
                }
            }

            #################################################################################
            #endregion slot


            #region module
            #################################################################################

            # module start
            $EvalParams.Regex = [regex] "^\s+NIM\[([03])\](?!:\s+Not\sPresent)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                if ($new.Model -match '^SSA-') {
                    continue
                }
                Write-Verbose "$VerbosePrefix $i`: module started: $Eval"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
                $new.Slot = $CurrentSlot
                $new.Module = $Eval
                $ReturnObject += $new
                $InModule = $true
                continue
            }

            if ($InModule) {
                # model
                $EvalParams.Regex = [regex] "^\s+Model:\s+(.+)"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    $new.Model = $Eval
                    continue
                }

                # replace model with part number when model is not available
                $EvalParams.Regex = [regex] "^\s+Part\sNumber:\s+(.+)"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    if (-not $new.Model) {
                        $PartNumberMap = @{
                            '9404324' = 'SOK1208-0104'
                        }
                        $new.Model = $PartNumberMap.$Eval
                    }
                    continue
                }

                # serial
                $EvalParams.Regex = [regex] "^\s+Serial\sNumber:\s+(.+)"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    Write-Verbose "$VerbosePrefix $i`: module complete"
                    $new.Serial = $Eval
                    $new = "" | Select Model # dummy for the remaing models
                    continue
                }
            }

            #################################################################################
            #endregion module

            #################################################################################
            #endregion s-series

            #region securestack
            #################################################################################

            # unit start
            $EvalParams.Regex = [regex] "^\s+UNIT\s(\d+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: module started: $Eval"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
                $new.Slot = $Eval
                $ReturnObject += $new
                continue
            }

            # model
            $EvalParams.Regex = [regex] "^\s+Model:\s+(.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                if (-not $new) {
                    Write-Verbose "$VerbosePrefix not stacked"
                    $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
                    $new.Slot = 1
                    $ReturnObject += $new
                }
                $new.Model = $Eval
                continue
            }

            # serial
            $EvalParams.Regex = [regex] "^\s+Serial\sNumber:\s+(.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.Serial = $Eval
                continue
            }

            # firmware
            $EvalParams.Regex = [regex] "^\s+Firm[wW]are\sVersion:\s+(.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.Firmware = $Eval
                continue
            }

            #################################################################################
            #endregion securestack
<#
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
                Write-Verbose "$VerbosePrefix $i`: vlan: clear egress 1"
                $ThesePorts = $Eval.Groups['ports'].Value
                $ThesePorts = Resolve-PortString -PortString $ThesePorts -SwitchType 'Eos'
                Write-Verbose "$VerbosePrefix $i`: vlan: $($LookupPorts.Count) ports to be cleared"
                $LookupPorts = $Ports | Where-Object { $ThesePorts -contains $_.Name }
                Write-Verbose "$VerbosePrefix $i`: vlan: $($LookupPorts.Count) ports"
                foreach ($p in $LookupPorts) {
                    if ($p.UntaggedVlan -eq 1) {
                        $p.UntaggedVlan = $null
                    }
                    if ($p.TaggedVlan -contains 1) {
                        $p.TaggedVlan = $P.TaggedVlan | Where-Object { $_ -ne 1 }
                    }
                }
            }

            # vlan egress
            $EvalParams.Regex = [regex] "set\ vlan\ egress\ (?<id>\d+)\ (?<ports>.+?)\ (?<tagging>.+)"
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
            } #>
        }
    }
    return $ReturnObject
}