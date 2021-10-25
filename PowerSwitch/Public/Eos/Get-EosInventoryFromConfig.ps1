function Get-EosInventoryFromConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosInventoryFromConfig:"

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

        #region kseries
        ################################################################################

        $Regex = [regex] '#\s+1\s+(KK.+)'
        $Eval = Get-RegexMatch $Regex $entry -ReturnGroupNumber 1
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: K-Series Output Started"

            $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
            $new.Slot = 'Chassis'
            $new.Model = 'K-Series'
            $ReturnObject += $new

            $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
            $new.Slot = '1'
            $new.Model = $Eval
            $ReturnObject += $new

            $KeepGoingKSeries = $true
            continue
        }

        if ($KeepGoingKSeries) {
            $Regex = [regex] '#\ssystem'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                if ($ReturnObject.Count -gt 8) {
                    $ReturnObject[0].Model = 'K-10'
                }
                Write-Verbose "$VerbosePrefix $i`: K-Series Output complete"
                break
            }

            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry

            # set linecard 1 KT2006-0224
            $EvalParams.Regex = [regex] "^set\ linecard\ (?<slot>\d+)\ (?<model>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
                $new.Slot = $Eval.Groups['slot'].Value
                $new.Model = $Eval.Groups['model'].Value
                $ReturnObject += $new
                continue
            }
        }

        ################################################################################
        #endregion kseries

        #region sseries
        ################################################################################

        $Regex = [regex] '#\s+(?<slot>\d+)\s+(?<model>S.+)'
        $Eval = Get-RegexMatch $Regex $entry
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: S-Series Output Started"

            $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
            $new.Slot = $Eval.Groups['slot'].Value
            $new.Model = $Eval.Groups['model'].Value
            $ReturnObject += $new

            $KeepGoingSSeries = $true
            continue
        }

        if ($KeepGoingSSeries) {
            $Regex = [regex] '#\ssystem'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                Write-Verbose "$VerbosePrefix $i`: S-Series Output complete"
                break
            }
        }

        ################################################################################
        #endregion sseries

        #region securestack
        ################################################################################

        $SwitchTypes = @{
            '1' = 'C5G124-24'
            '2' = 'C5K125-24'
            '3' = 'C5K175-24'
            '4' = 'C5K125-24P2'
            '5' = 'C5G124-24P2'
            '6' = 'C5G124-48'
            '7' = 'C5K125-48'
            '8' = 'C5K125-48P2'
            '9' = 'C5G124-48P2'
        }

        $Regex = [regex] '#system'
        $Eval = Get-RegexMatch $Regex $entry
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: SecureStack Output Started"

            $KeepGoingSecureStack = $true
            continue
        }

        if ($KeepGoingSecureStack) {
            $Regex = [regex] '#vlan'
            $Eval = Get-RegexMatch $Regex $entry
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: SecureStack Output complete"
                break
            }

            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry

            # set switch member 1 8
            $EvalParams.Regex = [regex] "^set\ switch\ member\ (?<slot>\d+)\ (?<model>\d+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new = "" | Select-Object Slot, Module, Model, Serial, Firmware, Status
                $new.Slot = $Eval.Groups['slot'].Value

                $SlotType = $Eval.Groups['model'].Value
                $new.Model = $SwitchTypes.$SlotType

                $ReturnObject += $new
                continue
            }
        }

        ################################################################################
        #endregion securestack
    }
    return $ReturnObject
}