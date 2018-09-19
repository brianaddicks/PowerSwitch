function Get-EosIpInterface {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $True)]
        [string]$Name
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosIpInterface:"

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

        $Regex = [regex] '^configure terminal$'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: vlan: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # interface <name>
            if ($Name) {
                $EvalParams.Regex = [regex] "^\ +interface\ ($Name)"
            } else {
                $EvalParams.Regex = [regex] "^\ +interface\ (.+)"
            }
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $New = [IpInterface]::new($Eval)

                $EvalParams.Regex = [regex] "vlan\.0\.(\d+)"
                $CheckVlan = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
                if ($CheckVlan) {
                    $New.VlanId = $CheckVlan
                }

                $ReturnArray += $New
                $InInterface = $true
                continue :fileloop
            }

            if ($InInterface) {
                # interface <name>
                $EvalParams.Regex = [regex] "^\ +ip\ address\ (?<ip>$IpRx)\ (?<mask>$IpRx)"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    $New.IpAddress += ($Eval.Groups['ip'].Value + '/' + (ConvertTo-MaskLength $Eval.Groups['mask'].Value))
                    continue :fileloop
                }

                # ip pim <mode>
                $EvalParams.Regex = [regex] "^\ +ip\ pim\ (.+)"
                $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
                if ($Eval) {
                    $New.PimMode = $Eval
                    continue :fileloop
                }

                # ip helper-address <helper>
                $EvalParams.Regex = [regex] "^\ +ip\ helper-address\ (.+)"
                $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
                if ($Eval) {
                    $New.IpHelper += $Eval
                    continue :fileloop
                }

                # no shutdown
                $EvalParams.Regex = [regex] "^\ +no\ shutdown"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    $New.Enabled = $true
                    continue :fileloop
                }

                # no ip redirects
                $EvalParams.Regex = [regex] "^\ +no\ ip\ redirects"
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    $New.IpRedirectsEnabled = $false
                    continue :fileloop
                }

                # exit interface
                $Regex = [regex] '^\ +exit'
                $Match = Get-RegexMatch $Regex $entry
                if ($Match) {
                    if ($Name) {
                        break
                    } else {
                        $InInterface = $false
                        continue :fileloop
                    }
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