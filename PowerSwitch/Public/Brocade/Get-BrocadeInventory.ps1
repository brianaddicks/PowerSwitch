function Get-BrocadeInventory {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-BrocadeInventory:"

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
    $ReturnObject = "" | Select-Object Hostname, StackMember, ChassisMember, CopperPortTotal, FiberPortTotal, OneGigCopperPortCount, OneGigFiberCount, TenGigFiberCount, FortyGigFiberCount
    $ReturnObject.StackMember = @()
    $ReturnObject.ChassisMember = @()
    $ReturnObject.CopperPortTotal = 0
    $ReturnObject.FiberPortTotal = 0
    $ReturnObject.OneGigCopperPortCount = 0
    $ReturnObject.OneGigFiberCount = 0
    $ReturnObject.TenGigFiberCount = 0
    $ReturnObject.FortyGigFiberCount = 0

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

        # check for stacking
        $EvalParams.Regex = [regex] "^stack\ unit\ (\d+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $StackNumber = $Eval
            Write-Verbose "$VerbosePrefix $i`: stack: $StackNumber config started"
            continue
        }




        if ($StackNumber) {
            # stack switches
            # stack unit 1
            #   module 1 icx6610-48p-poe-port-management-module
            #   module 2 icx6610-qsfp-10-port-160g-module
            #   module 3 icx6610-8-port-10g-dual-mode-module
            $EvalParams.Regex = [regex] "^\s*module\ (?<num>\d+)\ (?<model>(?<bladetype>icx\d+)-((?<count>\d+)(?<porttype>p)-poe|(?<porttype>qsfp)-\d+|(?<count>\d+))-port-(?<speed>.+?)-.+)"
        } else {
            # chassis switches
            # module 1 fi-sx6-8-port-10gig-fiber-module
            # module 1 fi-sx6-48-port-gig-copper-poe-module
            # module 1 fi-sx6-24-port-1gig-fiber-module
            # module 1 fi-sx-0-port-management-module
            # module 1 fi-sx6-xl-0-port-management-module
            $EvalParams.Regex = [regex] '^\s*module\ (?<num>\d+)\ (?<model>(?<bladetype>fi-sx\d?(-xl)?)-(?<count>\d+)-port(-(?<speed>\d*?[a-z]+))?-(?<porttype>.+)(-(?<poe>poe|management))?-module)'
        }
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            if ($StackNumber) {
                $NewBlade = "" | Select-Object Number, Module, Model
                $NewBlade.Number = $StackNumber
                $NewBlade.Module = $Eval.Groups['num'].Value
                $ReturnObject.StackMember += $NewBlade
            } else {
                $NewBlade = "" | Select-Object Number, Model
                $NewBlade.Number = $Eval.Groups['num'].Value
                $ReturnObject.ChassisMember += $NewBlade
            }
            $NewBlade.Model = @()

            Write-Verbose "$VerbosePrefix $i`: module: config started"
            #$BladeNumber = $Eval.Groups['num'].Value
            Write-Verbose "$VerbosePrefix $i`: module: decoding blade: $BladeNumber"
            $BladeType = $Eval.Groups['bladetype'].Value
            $PortSpeed = $Eval.Groups['speed'].Value
            $PortType = $Eval.Groups['porttype'].Value
            $PortCount = [int]$Eval.Groups['count'].Value
            $PortPoe = $Eval.Groups['poe'].Value

            Write-Verbose "$VerbosePrefix $i`: module: decoding blade: BladeType: $BladeType"
            Write-Verbose "$VerbosePrefix $i`: module: decoding blade: PortSpeed: $PortSpeed"
            Write-Verbose "$VerbosePrefix $i`: module: decoding blade: PortType: $PortType"

            if (($PortType -eq 'qsfp') -and ($PortSpeed -eq '160g')) {
                Write-Verbose "$VerbosePrefix $i`: module: decoding blade: adjusting for 4x40gig"
                $PortCount = 4
                $PortSpeed = '40gig'
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

            $NewBlade.Model += $Eval.Groups['model'].Value
            continue
        }

        $EvalParams.Regex = [regex] "^hostname\ (.+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Hostname = $Eval
            continue
        }
    }

    $ReturnObject
}