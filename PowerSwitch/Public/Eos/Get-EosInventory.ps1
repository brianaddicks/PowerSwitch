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
            continue
        }

        if ($entry -match '->') {
            if ($InModule) {
                $InModule = $false
                Write-Verbose "$VerbosePrefix $i`: module output complete"
            }
            if ($SlotStart) {
                $SlotStart = $false
                Write-Verbose "$VerbosePrefix $i`: slot output complete"
            }
        }
        ###########################################################################################
        # Check for the Section

        $Regex = [regex] 'show\ ver(sion)?$'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: 'show version' found"
            $SlotStart = $true
            continue
        }

        if ($SlotStart) {
            $Regex = [regex] '^(-+\ +)+-+$'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                Write-Verbose "$VerbosePrefix $i`: module output starting"
                $InModule = $true
                continue
            }
        }

        if ($InModule) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # slot/module/model/serial
            $EvalParams.Regex = [regex] "^((?<slot>\d+)\s+((?<module>\d+)\s+)?)?(?<model>[^\ ]+)\s+?(?<serial>[^\ ]+)"
            if ($SwitchType -eq 'Chassis') {
                $EvalParams.Regex = [regex] "^(?<slot>\d+)\s+((?<module>\d+)\s+)?(?<model>[^\ ]+)\s+?(?<serial>[^\ ]+)"
            }
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Slot++
                Write-Verbose "$VerbosePrefix $i`: slot found"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware

                $new.Slot = $Eval.Groups['slot'].Value
                $new.Module = $Eval.Groups['module'].Value
                $new.Model = $Eval.Groups['model'].Value
                $new.Serial = $Eval.Groups['serial'].Value

                if (!($new.Slot)) {
                    $SwitchType = 'Stackable'
                    $new.Slot = $Slot
                } else {
                    $SwitchType = 'Chassis'
                }

                Write-Verbose "$VerbosePrefix $i`: switchtype $SwitchType"

                $ReturnArray += $new
            }

            # firmware version
            $EvalParams.Regex = [regex] "^\s+?Fw:(\ )?(?<fw>[\d\.]+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.Firmware = $Eval.Groups['fw'].Value
            }
        }

        if ($SwitchType -eq 'Chassis') {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # Chassis Model
            $EvalParams.Regex = [regex] "^\s+?Chassis\ Type:\s+(.+?)\("
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: found chassis"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware

                $new.Slot = 'Chassis'
                $new.Model = $Eval

                $ReturnArray += $new
                $InChassis = $true
            }

            if ($InChassis) {
                # Chassis Serial
                $EvalParams.Regex = [regex] "^\s+?Chassis\ Serial\ Number:\s+(.+)"
                $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
                if ($Eval) {
                    $new.Serial = $Eval
                    #$InChassis = $false
                }

                # Chassis Fan for break
                $EvalParams.Regex = [regex] "^\s+?Chassis\ Fan"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    Write-Verbose "$VerbosePrefix $i`: chassis output complete"
                    break fileloop
                }
            }

            # Power Supply Slot
            $EvalParams.Regex = [regex] "^\s+?Chassis\ Power\ Supply\ (\d+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: found power supply"
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware

                $new.Slot = "PS$Eval"

                $ReturnArray += $new
                $InPowerSupply = $true
            }

            if ($InPowerSupply) {
                # Power Supply Model
                $EvalParams.Regex = [regex] "^\s+?Type\ =\ ([^\ ]+)"
                $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
                if ($Eval) {
                    Write-Verbose "$VerbosePrefix $i`: found power supply model"
                    $new.Model = $Eval
                    $InPowerSupply = $false
                }
            }
        }

    }
    return $ReturnArray
}