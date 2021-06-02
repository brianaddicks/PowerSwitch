function Get-BrocadeIpInterface {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-BrocadeIpInterface:"

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

        if ($entry -eq "") {
            if ($InModule) {
                break
            }
            continue
        }

        ###########################################################################################
        # Check for the Section

        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry
        $EvalParams.Regex = [regex] "^interface\ (?<type>ve|loopback)\ (?<number>\d+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: interface found: $Eval"
            $Type = $Eval.Groups['type'].Value
            if ($Type -eq 've') {
                $Type = 'Vlan'
            }
            $Number = $Eval.Groups['number'].Value
            $Name = $Type + ' ' + $Number
            $new = [IpInterface]::new($Name)
            if ($Type -eq 'Vlan') {
                $new.VlanId = $Number
            }
            $new.Enabled = $true
            $new.IpForwardingEnabled = $true
            $ReturnArray += $new
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry

            # ip address
            $EvalParams.Regex = [regex] "^\ +ip\ address\ (?<ip>$IpRx)\ (?<mask>$IpRx)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $IpAndMask = $Eval.Groups['ip'].Value
                $IpAndMask += '/' + ($Eval.Groups['mask'].Value | ConvertTo-MaskLength)
                $new.IpAddress += $IpAndMask
                continue
            }

            # ip address cidr
            $EvalParams.Regex = [regex] "^\ +ip\ address\ (?<ip>$IpRx\/\d+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $IpAndMask = $Eval.Groups['ip'].Value
                $new.IpAddress += $IpAndMask
                continue
            }

            # ip helper-address
            $EvalParams.Regex = [regex] "^\ +ip\ helper-address\ \d+\ ($IpRx)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.IpHelperEnabled = $true
                $new.IpHelper += $Eval
                continue
            }

            # ip ospf area 1.1.1.1
            $EvalParams.Regex = [regex] "^\ +ip\ ospf\ area\ ($IpRx)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.OspfArea = $Eval
                continue
            }

            # ip ospf passive
            $EvalParams.Regex = [regex] "^\ +ip\ ospf\ passive"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.OspfPassive = $true
                continue
            }

            # ip access-group <aclname> <direction>
            $EvalParams.Regex = [regex] "^\ +ip\ access-group\ (?<name>.+?)\ (?<direction>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.AccessList = $Eval.Groups['name'].Value
                $new.AccessListDirection = $Eval.Groups['direction'].Value
                continue
            }

            # ip pim-sparse
            $EvalParams.Regex = [regex] "^\ +ip\ pim-sparse"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.IpMulticastForwardingEnabled = $true
                $new.PimMode = 'sparse'
                continue
            }

            # ip pim passive
            $EvalParams.Regex = [regex] "^\ +ip\ pim\ passive"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.PimPassive = $true
                continue
            }

            # shutdown
            $EvalParams.Regex = [regex] "^\ +shutdown"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.Enabled = $false
                continue
            }

            # end of interface
            $EvalParams.Regex = [regex] "^!"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $KeepGoing = $false
                continue
            }
        }
    }
    return $ReturnArray
}