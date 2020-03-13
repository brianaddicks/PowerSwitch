function Get-HpArubaInventory {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpArubaInventory:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath -PathType Leaf) {
            Write-Verbose "$VerbosePrefix ConfigPath is file"
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $ReturnObject = "" | Select-Object Hostname, StackMember, ChassisMember, `
        CopperPortTotal, OneGigCopperPortCount, OneGigFiberCount, `
        FiberPortTotal, TenGigFiberCount, FortyGigFiberCount, `
        PowerSupply, Transceiver
    $ReturnObject.StackMember = @()
    $ReturnObject.ChassisMember = @()
    $ReturnObject.CopperPortTotal = 0
    $ReturnObject.FiberPortTotal = 0
    $ReturnObject.OneGigCopperPortCount = 0
    $ReturnObject.OneGigFiberCount = 0
    $ReturnObject.TenGigFiberCount = 0
    $ReturnObject.FortyGigFiberCount = 0
    $ReturnObject.PowerSupply = @()
    $ReturnObject.Transceiver = @()

    #region moduleMap
    ###########################################################################################
    # was originally doing this with regex, but was afraid of missing something

    $ModuleMap = @{ }

    # J9150D
    $ModuleMap.'J9150D' = @{
        ProductType      = 'Transceiver'
        Description      = 'Aruba 10G SFP+ LC SR 300m MMF XCVR'
        SpeedInMbps      = 10000
        SubType          = 'SR'
        DistanceInMeters = 300
        CableType        = 'Multimode Fiber'
    }

    # J9151E
    $ModuleMap.'J9151E' = @{
        ProductType      = 'Transceiver'
        Description      = 'Aruba 10G SFP+ LC LR 10km SMF XCVR'
        SpeedInMbps      = 10000
        SubType          = 'LR'
        DistanceInMeters = 10000
        CableType        = 'Singlemode Fiber'
    }

    # J9281D
    $ModuleMap.'J9281D' = @{
        ProductType      = 'Transceiver'
        Description      = 'Aruba 10G SFP+ to SFP+ 1m DAC Cable'
        SpeedInMbps      = 10000
        SubType          = 'DAC'
        DistanceInMeters = 1
        CableType        = 'Direct Attach'
    }

    # JH234A
    $ModuleMap.'JH234A' = @{
        ProductType      = 'DAC'
        Description      = 'HPE X242 40G QSFP+ to QSFP+ 1m DAC Cable'
        SpeedInMbps      = 40000
        PortType         = 'QSFP-Plus'
        DistanceInMeters = 1
    }

    # J9734A
    $ModuleMap.'J9734A' = @{
        ProductType      = 'StackCable'
        Description      = 'Aruba 2920/2930M 0.5m Stacking Cable'
        DistanceInMeters = .5
    }

    # J9735A
    $ModuleMap.'J9735A' = @{
        ProductType      = 'StackCable'
        Description      = 'Aruba 2920/2930M 1m Stacking Cable'
        DistanceInMeters = 1
    }

    # J9736A
    $ModuleMap.'J9736A' = @{
        ProductType      = 'StackCable'
        Description      = 'Aruba 2920/2930M 3m Stacking Cable'
        DistanceInMeters = 3
    }

    # JL083A
    $ModuleMap.'JL083A' = @{
        BladeType   = 'Module'
        Description = 'Aruba 3810M/2930M 4SFP+ MACsec Module'
        Port        = @(
            @{
                SpeedInMbps = 10000
                PortType    = 'fiber'
                PortCount   = 4
                PortPoe     = $false
            }
        )
    }

    # JL086A
    $ModuleMap.'JL086A' = @{
        ProductType = 'PowerSupply'
        Description = 'Aruba X372 54VDC 680W Power Supply'
        Wattage     = 680
    }

    # JL322A
    $ModuleMap.'JL322A' = @{
        ProductType = 'Switch'
        Description = 'Aruba 2930M 48G PoE+ 1-slot Switch'
        Port        = @(
            @{
                SpeedInMbps = 1000
                PortType    = 'copper'
                PortCount   = 48
                PortPoe     = $true
            }
            @{
                SpeedInMbps = 1000
                PortType    = 'fiber'
                PortCount   = 4
                PortPoe     = $false
            }
        )
    }

    # JL325A
    $ModuleMap.'JL325A' = @{
        BladeType   = 'Module'
        Description = 'Aruba 2930 2-port Stacking Module'
        Port        = @(
            @{
                SpeedInMbps = 0
                PortType    = 'stack'
                PortCount   = 2
                PortPoe     = $false
            }
        )
    }

    # JL479A
    $ModuleMap.'JL479A' = @{
        ProductType = 'Switch'
        Description = 'Aruba 8320 48 10/6 40 X472 5 2 Bundle'
        Port        = @(
            @{
                SpeedInMbps = 10000
                PortType    = 'fiber'
                PortCount   = 48
                PortPoe     = $false
            }
            @{
                SpeedInMbps = 40000
                PortType    = 'fiber'
                PortCount   = 6
                PortPoe     = $false
            }
        )
    }

    ###########################################################################################
    #endregion moduleMap


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
        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry


        $EvalParams.Regex = [regex] "^\s+(?<stackmember>\d+)\s+(?<psnumber>\d+)\s+(?<model>J[^\ ]+?)\s+(?<serial>[^\ ]+?)\s+(?<state>(Not\ )?Powered)\s+(?<powertype>AC|DC)\s(?<acvoltage>\d+)V\/(?<dcvoltage>\d+)V\s+(?<wattage>\d+)\s+(?<maxwattage>\d+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: psu: psu found"
            $NewPsu = [PowerSupply]::new()

            $Model = $Eval.Groups['model'].Value

            $NewPsu.Model = $Model
            $NewPsu.StackMember = $Eval.Groups['stackmember'].Value
            $NewPsu.PsuNumber = $Eval.Groups['psnumber'].Value
            $NewPsu.SerialNumber = $Eval.Groups['serial'].Value
            $NewPsu.PowerType = $Eval.Groups['powertype'].Value
            $NewPsu.AcVoltage = $Eval.Groups['acvoltage'].Value
            $NewPsu.DcVoltage = $Eval.Groups['dcvoltage'].Value
            $NewPsu.CurrentWattage = $Eval.Groups['wattage'].Value
            $NewPsu.MaxWattage = $Eval.Groups['maxwattage'].Value

            if ($Eval.Groups['state'].Value -eq 'Not Powered') {
                $NewPsu.IsPowered = $false
            } else {
                $NewPsu.IsPowered = $true
            }

            $NewPsu.Description = $ModuleMap.$Model.Description

            $ReturnObject.PowerSupply += $NewPsu
            continue
        }

        #region transceiverinfo
        #######################################################################################

        # section start
        $EvalParams.Regex = [regex] "^Transceiver\ Technical\ Information"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $InTransceiverSection = $true
            Write-Verbose "$VerbosePrefix $i`: transceiver: section start"
            continue
        }

        if ($InTransceiverSection) {

            # section end
            $EvalParams.Regex = [regex] "#"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $InTransceiverSection = $false
                Write-Verbose "$VerbosePrefix $i`: transceiver: section end"
                continue
            }

            # transceiver
            $EvalParams.Regex = [regex] "^\s+(?<port>[^\ ]+?)\s+(?<type>[^\ ]+?)\s+(?<model>J[^\ ]+?)\s+(?<serial>[^\ ]+?)\s+"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {

                $NewTransceiver = [Transceiver]::new()

                $Model = $Eval.Groups['model'].Value
                Write-Verbose "$VerbosePrefix $i`: transceiver: adding $Model"

                $NewTransceiver.Model = $Model
                $NewTransceiver.Description = $ModuleMap.$Model.Description
                $NewTransceiver.CableType = $ModuleMap.$Model.CableType
                $NewTransceiver.SpeedInMbps = $ModuleMap.$Model.SpeedInMbps
                $NewTransceiver.DistanceInMeters = $ModuleMap.$Model.DistanceInMeters

                # Parse Type/SubType
                $Type = $Eval.Groups['type'].Value
                Write-Verbose "$VerbosePrefix $i`: transceiver: parsing type: $Type"
                switch -Regex ($Type) {
                    'SFP+' {
                        $ThisEvalParams = @{ }
                        $ThisEvalParams.StringToEval = $Type
                        $ThisEvalParams.Regex = [regex] "(SFP\+)(.+)"
                        $ThisEval = Get-RegexMatch @ThisEvalParams
                        $Type = $ThisEval.Groups[1].Value
                        $SubType = $ThisEval.Groups[2].Value
                    }
                }

                $NewTransceiver.Type = $Type
                $NewTransceiver.SubType = $SubType

                $ReturnObject.Transceiver += $NewTransceiver
                continue
            }
        }

        #######################################################################################
        #endregion transceiverinfo

        #region stacking
        #######################################################################################

        # section start
        $EvalParams.Regex = [regex] "^stacking$"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $InStackingSection = $true
            Write-Verbose "$VerbosePrefix $i`: stacking: section start"
            continue
        }

        if ($InStackingSection) {

            # section end
            $EvalParams.Regex = [regex] "^exit"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $InStackingSection = $false
                Write-Verbose "$VerbosePrefix $i`: stacking: section end"
                continue
            }

            # transceiver
            $EvalParams.Regex = [regex] '^\s+member\s(?<number>\d+)\stype\s"(?<model>.+?)"\smac-address\s(?<mac>[^\ ]+?)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix looking up StackMember: $($Eval.Groups['number'].Value)"
                $StackLookup = $ReturnObject.StackMember | Where-Object { ($_.Number -eq $Eval.Groups['number'].Value) -and ($_.Slot -eq 0) }

                if ($StackLookup) {
                    $Model = $Eval.Groups['model'].Value
                    $StackLookup.Model = $Model
                    $StackLookup.Description = $ModuleMap.$Model.Description

                    $ModuleLookup = $ModuleMap.$Model

                    foreach ($p in $ModuleLookup.Port) {
                        switch ($p.PortType) {
                            'copper' {
                                $ReturnObject.CopperPortTotal += $p.PortCount
                                switch ($p.SpeedInMbps) {
                                    1000 {
                                        $ReturnObject.OneGigCopperPortCount += $p.PortCount
                                        break
                                    }
                                    default {
                                        Write-Warning "$VerbosePrefix unhandled port speed $($p.PortType) $($p.SpeedInMbps)"
                                        break
                                    }
                                }
                                break
                            }
                            'fiber' {
                                $ReturnObject.FiberPortTotal += $p.PortCount
                                switch ($p.SpeedInMbps) {
                                    1000 {
                                        $ReturnObject.OneGigFiberCount += $p.PortCount
                                        break
                                    }
                                    default {
                                        Write-Warning "$VerbosePrefix unhandled port speed $($p.PortType) $($p.SpeedInMbps)"
                                        break
                                    }
                                }
                                break
                            }
                            default {
                                Write-Warning "$VerbosePrefix unhandled port type $($p.PortType)"
                            }
                        }
                    }
                } else {
                    Write-Warning "$VerbosePrefix no lookup found "
                }

                continue
            }
        }

        #######################################################################################
        #endregion stacking

        #region systeminfo
        #######################################################################################

        # section start
        $EvalParams.Regex = [regex] "^\s+Member\s+:(\d+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: switch: adding member $Eval"
            $InSwitch = $true
            $NewSwitch = [SwitchModule]::new()
            $NewSwitch.Number = $Eval
            $NewSwitch.Slot = 0

            $ReturnObject.StackMember += $NewSwitch
            continue
        }

        if ($InSwitch) {

            # mac address
            $EvalParams.Regex = [regex] "^\s+MAC\sAddr\s+:\s([^\ ]+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: switch: $($NewSwitch.Member): adding mac address"
                $NewSwitch.MacAddress = $Eval
                continue
            }

            # serial number
            $EvalParams.Regex = [regex] "^\s+Serial\sNumber\s+:\s([^\ ]+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: switch: $($NewSwitch.Member): adding serial number"
                $NewSwitch.SerialNumber = $Eval

                $InSwitch = $false
                continue
            }
        }

        #######################################################################################
        #endregion systeminfo

        #region module
        #######################################################################################

        # section start
        $EvalParams.Regex = [regex] "ID\s+Slot\s+Module\sDescription"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $InModuleSection = $true
            Write-Verbose "$VerbosePrefix $i`: module: section start"
            continue
        }

        if ($InModuleSection) {

            # section end
            $EvalParams.Regex = [regex] "^[^\s]+"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $InModuleSection = $false
                Write-Verbose "$VerbosePrefix $i`: module: section end"
                continue
            }

            # module
            $EvalParams.Regex = [regex] '^\s+(?<member>\d+)\s+(?<slot>[^\ ]+)\s+(?<description>.+?)\s{2,}(?<serial>[^\ ]+?)\s+(?<state>.+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Global:TestEval = $Eval
                Write-Verbose "$VerbosePrefix $i`: module: module found"
                $NewModule = [SwitchModule]::new()
                $NewModule.Number = $Eval.Groups['member'].Value
                $NewModule.Slot = $Eval.Groups['slot'].Value
                $NewModule.SerialNumber = $Eval.Groups['serial'].Value

                $ModelRx = [regex] 'J[0-9A-Z]+(?=\s)'
                $Model = $ModelRx.Match($Eval.Groups['description'].Value).Value
                $NewModule.Model = $Model
                $ModuleLookup = $ModuleMap.$Model
                $NewModule.Description = $ModuleLookup.Description

                $ReturnObject.StackMember += $NewModule

                foreach ($p in $ModuleLookup.Port) {
                    switch ($p.PortType) {
                        'copper' {
                            $ReturnObject.CopperPortTotal += $p.PortCount
                            switch ($p.SpeedInMbps) {
                                1000 {
                                    $ReturnObject.OneGigCopperPortCount += $p.PortCount
                                    break
                                }
                                default {
                                    Write-Warning "$VerbosePrefix unhandled port speed $($p.PortType) $($p.SpeedInMbps)"
                                    break
                                }
                            }
                            break
                        }
                        'fiber' {
                            $ReturnObject.FiberPortTotal += $p.PortCount
                            switch ($p.SpeedInMbps) {
                                1000 {
                                    $ReturnObject.OneGigFiberCount += $p.PortCount
                                    break
                                }
                                10000 {
                                    $ReturnObject.TenGigFiberCount += $p.PortCount
                                    break
                                }
                                40000 {
                                    $ReturnObject.FortyGigFiberCount += $p.PortCount
                                    break
                                }
                                default {
                                    Write-Warning "$VerbosePrefix unhandled port speed $($p.PortType) $($p.SpeedInMbps)"
                                    break
                                }
                            }
                            break
                        }
                        default {
                            Write-Warning "$VerbosePrefix unhandled port type $($p.PortType)"
                        }
                    }
                }

                continue
            }
        }

        #######################################################################################
        #endregion module

        <# # check for stacking
        $EvalParams.Regex = [regex] "^stack\ unit\ (\d+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $StackNumber = $Eval
            Write-Verbose "$VerbosePrefix $i`: stack: $StackNumber config started"
            continue
        }

        $EvalParams.Regex = [regex] "^\s*module\ (?<num>\d+)\ (?<model>.+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $Model = ($Eval.Groups['model'].Value).Trim()
            $Number = $Eval.Groups['num'].Value
            $ModuleMapEntry = $BrocadeModuleMap.$Model

            if ($ModuleMapEntry) {
                $NewBlade = "" | Select-Object Number, Module, Model, MacAddress
                $NewBlade.Model = $Model
                if ($StackNumber) {
                    $NewBlade.Number = $StackNumber
                    $NewBlade.Module = $Number
                    $ReturnObject.StackMember += $NewBlade
                } else {
                    #$NewBlade.Number = $Eval.Groups['num'].Value
                    $NewBlade.Number = $Number
                    $ReturnObject.ChassisMember += $NewBlade
                }
                Write-Verbose "$VerbosePrefix $i`: module: config started"
                Write-Verbose "$VerbosePrefix $i`: module: decoding blade: $BladeNumber"

                $BladeType = $ModuleMapEntry.BladeType
                $PortSpeed = $ModuleMapEntry.PortSpeed
                $PortType = $ModuleMapEntry.PortType
                $PortCount = $ModuleMapEntry.PortCount
                $PortPoe = $ModuleMapEntry.PortPoe

                Write-Verbose "$VerbosePrefix $i`: module: decoding blade: BladeType: $BladeType"
                Write-Verbose "$VerbosePrefix $i`: module: decoding blade: PortSpeed: $PortSpeed"
                Write-Verbose "$VerbosePrefix $i`: module: decoding blade: PortType: $PortType"

                if (($PortType -eq 'qsfp') -and ($PortSpeed -eq '160g')) {
                    Write-Verbose "$VerbosePrefix $i`: module: decoding blade: adjusting for 4x40gig"
                    $PortCount = 4
                    $PortSpeed = '40gig'
                }

                if ($PortType -eq 'sfp-plus') {
                    $PortSpeed = '10gig'
                    $PortType = 'fiber'
                }

                if ($PortSpeed -eq 'management') {
                    $PortSpeed = '1gig'
                }

                if ($PortSpeed -eq '10g') {
                    $PortSpeed = '10gig'
                    $PortType = 'fiber'
                }

                if (('' -eq $PortType) -and ($PortSpeed -eq '1gig')) {
                    $PortType = 'copper'
                }


                switch -Regex ($PortType) {
                    '^(copper-poe|p|copper)$' {
                        switch -Regex ($PortSpeed) {
                            '^(1gig|gig)$' {
                                Write-Verbose "$VerbosePrefix Current OneGigCopperCount: $($ReturnObject.OneGigCopperPortCount); Current CopperPortTotal: $($ReturnObject.CopperPortTotal)"
                                $ReturnObject.OneGigCopperPortCount += $PortCount
                                $ReturnObject.CopperPortTotal += $PortCount
                                Write-Verbose "$VerbosePrefix Adding $PortCount ports with speed $PortSpeed of type $PortType"
                            }
                            default {
                                Write-Verbose "$VerbosePrefix Adding $PortCount ports with speed $PortSpeed of type $PortType"
                            }
                        }
                    }
                    '^(fiber|qsfp)$' {
                        switch ($PortSpeed) {
                            '1gig' {
                                $ReturnObject.OneGigFiberCount += $PortCount
                                $ReturnObject.FiberPortTotal += $PortCount
                                Write-Verbose "$VerbosePrefix Adding $PortCount ports with speed $PortSpeed of type $PortType"
                            }
                            '10gig' {
                                $ReturnObject.TenGigFiberCount += $PortCount
                                $ReturnObject.FiberPortTotal += $PortCount
                                Write-Verbose "$VerbosePrefix Adding $PortCount ports with speed $PortSpeed of type $PortType"
                            }
                            '40gig' {
                                $ReturnObject.FortyGigFiberCount += $PortCount
                                $ReturnObject.FiberPortTotal += $PortCount
                                Write-Verbose "$VerbosePrefix Adding $PortCount ports with speed $PortSpeed of type $PortType"
                            }
                            default {
                                Write-Warning "$VerbosePrefix unhandled PortSpeed/PortType combination: $PortSpeed/$PortType"
                            }
                        }
                    }
                    'management' {
                        if ($PortCount -eq 0) {
                            Write-Verbose "$VerbosePrefix skipping management blade with $PortCount ports"
                        } else {
                            Write-Warning "$VerbosePrefix unhandled PortType: $PortType with count: $PortCount"
                        }
                    }
                    default {
                        Write-Warning "$VerbosePrefix unhandled PortType: $PortType"
                    }
                }
                continue
            } else {
                Write-Warning "$VerbosePrefix unmatched module detected on line $i`: |$Model|"
            }
        } #>

        $EvalParams.Regex = [regex] '^hostname\ "?(.+?)"?'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Hostname = $Eval
            continue
        }
    }

    $ReturnObject
}