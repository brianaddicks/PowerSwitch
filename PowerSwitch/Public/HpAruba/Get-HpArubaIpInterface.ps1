function Get-HpArubaIpInterface {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpArubaIpInterface:"

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

    #$DhcpRelays = Get-HpArubaRelayServerGroup -ConfigArray $LoopArray

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

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry
        $EvalParams.Regex = [regex] '^vlan\ (\d+)$'
        $EvalParams.LineNumber = $i

        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: interface found: $Eval"
            $Name = 'vlan' + $Eval
            $new = [IpInterface]::new($Name)
            $new.VlanId = $Eval
            $new.Enabled = $true
            $ReturnArray += $new
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry
            $EvalParams.LineNumber = $i

            # name "<name>"
            $EvalParams.Regex = [regex] '^\s+name\ "(.+?)"'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $new.Description = $Eval
                continue
            }

            # ip address
            $EvalParams.Regex = [regex] "^\ +ip\ address\ (?<ip>$IpRx)\ (?<mask>$IpRx)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $IpAndMask = $Eval.Groups['ip'].Value
                $IpAndMask += '/' + ($Eval.Groups['mask'].Value | ConvertTo-MaskLength)
                $new.IpAddress += $IpAndMask
                continue
            }

            # dhcp select relay
            $EvalParams.Regex = [regex] "^\ +dhcp\ select\ relay"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $DhcpSelectRelay = $true
                continue
            }

            # dhcp relay server-select 1
            if ($DhcpSelectRelay) {
                $EvalParams.Regex = [regex] "^\ +dhcp\ relay\ server\-select\ (\d+)"
                $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
                if ($Eval) {
                    $new.IpHelper = ($DhcpRelays | Where-Object { $_.GroupNumber -eq $Eval }).IpAddress
                    $DhcpSelectRelay = $false
                    continue
                }
            }

            # shutdown
            $EvalParams.Regex = [regex] "^\ +shutdown"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $new.Enabled = $false
                continue
            }

            # end of interface
            $EvalParams.Regex = [regex] "^\s+exit"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $KeepGoing = $false
                continue
            }
        }
    }
    return $ReturnArray | Where-Object { $_.IpAddress }
}