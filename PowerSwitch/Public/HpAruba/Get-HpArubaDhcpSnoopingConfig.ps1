function Get-HpArubaDhcpSnoopingConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpArubaDhcpSnoopingConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    $Ports = Get-HpArubaPortName -ConfigArray $LoopArray

    # Setup ReturnObject
    $ReturnObject = @{}
    $ReturnObject.Enabled = $false
    $ReturnObject.EnabledVlans = @()
    $ReturnObject.VerifyMacAddress = $True
    $ReturnObject.TrustedPort = @()
    $ReturnObject.TrustedServer = @()

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

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry
        $EvalParams.LineNumber = $i
        $EvalParams.ReturnGroupNumber = 1

        # dhcp-snooping authorized-server <server>
        $EvalParams.Regex = [regex] "^dhcp-snooping\ authorized-server\ (.+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.TrustedServer += $Eval
            continue
        }

        # dhcp-snooping vlan <vlans>
        $EvalParams.Regex = [regex] "^dhcp-snooping\ vlan\ (.+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.EnabledVlans += $Eval.split()
            continue
        }

        # interface config match
        $EvalParams.Regex = [regex] "^interface\ (.+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix Checking Interface: $Eval"
            $InInterface = $true
            $InterfaceName = $Eval
            continue
        }

        if ($InInterface) {
            # portfast
            $EvalParams.Regex = [regex] "^\ +dhcp-snooping\ (trust)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.TrustedPort += $InterfaceName
                continue
            }

            # End interface
            $EvalParams.Regex = [regex] '\s+(exit)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $InInterface = $false
                continue
            }
        }

        <# $EvalParams.ReturnGroupNumber = 1

        # set dhcpsnooping vlan <vlan-string> enable
        $EvalParams.Regex = [regex] "^set\ dhcpsnooping\ vlan\ (.+?)\ enable"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.EnabledVlans += (Resolve-VlanString -VlanString $Eval -SwitchType 'Eos')
        }

        # set dhcpsnooping verify mac-address disable
        $EvalParams.Regex = [regex] "^set\ dhcpsnooping\ verify\ mac-address\ (disable)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.VerifyMacAddress = $false
        }

        # set dhcpsnooping trust port <port> enable
        $EvalParams.Regex = [regex] "^set\ dhcpsnooping\ trust\ port\ (.+?)\ enable"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.TrustedPorts += $Eval
        }

        $Regex = [regex] '^#'
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            break
        } #>
    }
    return $ReturnObject
}