function Get-CiscoInventoryStream {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoInventory:"

<#     # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    } #>

    # Setup return Array
    $ReturnObject = @()
    $ShowModule = $false
    $ShowInventory = $false

    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down

    $file = New-Object System.IO.StreamReader -Arg $ConfigPath
    :fileloop while ($null -ne ($entry = $file.ReadLine())) {

    #:fileloop foreach ($entry in $LoopArray) {
        $i++

        # Write progress bar, we're only updating every 1000ms, if we do it every line it takes forever

<#         if ($StopWatch.Elapsed.TotalMilliseconds -ge 1000) {
            $PercentComplete = [math]::truncate($i / $TotalLines * 100)
            Write-Progress -Activity "Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
            $StopWatch.Reset()
            $StopWatch.Start()
        } #>

         if ($entry -eq "") {
            if ($ReturnObject.Count -gt 0) {
                if ($KeepGoingChassis) {
                    $KeepGoingChassis = $false
                    Write-Verbose "$VerbosePrefix $i`: chassis output complete"
                }
                if ($KeepGoingStack) {
                    $KeepGoingStack = $false
                    Write-Verbose "$VerbosePrefix $i`: stacking output complete"
                }
                if ($ShowModule -and $ShowInventory) {
                    Write-Verbose "$VerbosePrefix $i`: output complete"
                    break fileloop
                }
            }
            continue
        }

        ###########################################################################################
        # Check for the Section

        # stacking
        $Regex = [regex] '#show\sinventory$'
        $Eval = Get-RegexMatch $Regex $entry
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: inventory output started"
            $KeepGoingInventory = $true
            continue
        }

        # stacking
        $Regex = [regex] '^Switch\s+Ports\s+Model\s+SW\sVersion\s+SW\sImage'
        $Eval = Get-RegexMatch $Regex $entry
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: stacking output started"
            $KeepGoingStack = $true
            $ShowModule = $true
            continue
        }

        # chassis
        $Regex = [regex] '^(?<slot>Mod\s+)(?<portcount>Ports\s+)(?<cardtype>Card\sType\s+)(?<model>Model\s+)(?<serial>Serial\sNo\.)'
        $Eval = Get-RegexMatch $Regex $entry
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: chassis output started"
            $KeepGoingChassis = $true
            $ShowModule = $true

            $SlotLength = ($Eval.Groups['slot'].Value).Length
            $PortCountLength = ($Eval.Groups['portcount'].Value).Length
            $CardTypeLength = ($Eval.Groups['cardtype'].Value).Length
            $ModelLength = ($Eval.Groups['model'].Value).Length
            $SerialLength = ($Eval.Groups['serial'].Value).Length

            $ChassisRx = "(?<slot>[^-]{$SlotLength})"
            $ChassisRx += "(?<portcount>.{$PortCountLength})"
            $ChassisRx += "(?<cardtype>.{$CardTypeLength})"
            $ChassisRx += "(?<model>.{$ModelLength})"
            $ChassisRx += "(?<serial>.{$SerialLength})"

            $ChassisRx = [regex] $ChassisRx
            continue
        }

        if ($KeepGoingStack) {
            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry

            #region stackable
            #################################################################################

            # stack member
            # Switch Ports Model              SW Version        SW Image              Mode
            # *    1 62    C9300-48P          16.6.3            CAT9K_IOSXE           INSTALL
            $EvalParams.Regex = [regex] "^\*?\s+(?<slot>\d+?)\s+?(?<portcount>\d+?)\s+?(?<model>[^\s]+?)\s+?(?<version>[^\s]+?)\s+?(?<image>[^\s]+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: chassis found"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status, PortCount
                $new.Slot = $Eval.Groups['slot'].Value
                $new.Model = $Eval.Groups['model'].Value
                $new.PortCount = $Eval.Groups['portcount'].Value
                $new.Firmware = $Eval.Groups['image'].Value + ' ' + $Eval.Groups['version'].Value
                $ReturnObject += $new
                continue
            }

            #################################################################################
            #endregion stackable
        }

        if ($KeepGoingChassis) {
            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry

            #region chassis
            #################################################################################

            # stack member
            # Mod Ports Card Type                              Model              Serial No.
            # --- ----- -------------------------------------- ------------------ -----------
            # 1   48  48-port 10/100/1000 RJ45 EtherModule   WS-X6148A-GE-45AF  SAD093806Z9
            $EvalParams.Regex = $ChassisRx
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: chassis found"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status, PortCount
                $new.Slot = $Eval.Groups['slot'].Value.Trim()
                $new.Model = $Eval.Groups['model'].Value.Trim()
                $new.PortCount = $Eval.Groups['portcount'].Value.Trim()
                $ReturnObject += $new
                continue
            }

            #################################################################################
            #endregion chassis
        }

        if ($KeepGoingInventory) {
            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry

            # NAME: "TenGigabitEthernet0/1", DESCR: "10GBase-SR"
            # PID: X2-10GB-SR        , VID: V03  , SN: AGA1216X4VS
            $EvalParams.Regex = [regex] '^NAME:\s+"(?<name>.+?)",\s+DESCR:\s+"(?<description>.+?)"'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: inventory found"
                $SlotName = $Eval.Groups['name'].Value.Trim()
                $SlotLookup = $ReturnObject | Where-Object { $_.Slot -eq $SlotName }
                if ($SlotLookup) {
                    $SlotLookup.Module = $Eval.Groups['description'].Value.Trim()
                } else {
                    $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status, PortCount
                    $new.Slot = $Eval.Groups['name'].Value.Trim()
                    $new.Module = $Eval.Groups['description'].Value.Trim()
                    $ReturnObject += $new
                }
                continue
            }

            # PID: X2-10GB-SR        , VID: V03  , SN: AGA1216X4VS
            $EvalParams.Regex = [regex] '^PID:\s+(?<pid>.+?),\s+VID:\s+(?<vid>.+?),\s+SN:\s+(?<serial>.+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: inventory found"

                if ($SlotLookup) {
                    $SlotLookup.Model = $Eval.Groups['pid'].Value.Trim()
                    $SlotLookup.Serial = $Eval.Groups['serial'].Value.Trim()
                    Remove-Variable SlotLookup
                } else {
                    $new.Model = $Eval.Groups['pid'].Value.Trim()
                    if ($new.Model -eq 'Unspecified') {
                        $new.Module
                    }
                    #$new.VendorId = $Eval.Groups['vid'].Value
                    $new.Serial = $Eval.Groups['serial'].Value.Trim()
                }
                continue
            }

            if ($entry -eq '') {
                Write-Verbose "$VerbosePrefix $i`: empty line"
                $ShowInventory = $true
                continue
            }
        }
    }

    $file.Close()

    return $ReturnObject
}