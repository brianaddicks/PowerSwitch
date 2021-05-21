function Get-CiscoPortStatus {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoPortStatus:"

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

        $Regex = [regex] '(?x)
                          ^(?<port>Port\s+?)
                          (?<alias>Name\s+?)
                          (?<oper>Status\s+?)
                          (?<vlan>Vlan\s+?)
                          (?<duplex>Duplex\s+?)
                          (?<speed>\sSpeed\s+?)
                          (?<type>Type)'
        $Eval = Get-RegexMatch $Regex $entry
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: port status: output started"
            $KeepGoing = $true

            $PortLength = ($Eval.Groups['port'].Value).Length
            $AliasLength = ($Eval.Groups['alias'].Value).Length
            $OperLength = ($Eval.Groups['oper'].Value).Length
            $AdminLength = ($Eval.Groups['vlan'].Value).Length
            $SpeedLength = ($Eval.Groups['duplex'].Value).Length
            $DuplexLength = ($Eval.Groups['speed'].Value).Length

            $PortStatusRxString = "(?<name>.{$PortLength})"
            $PortStatusRxString += "(?<alias>.{$AliasLength})"
            $PortStatusRxString += "(?<oper>.{$OperLength})"
            $PortStatusRxString += "(?<vlan>.{$AdminLength})"
            $PortStatusRxString += "(?<duplex>.{$SpeedLength})"
            $PortStatusRxString += "(?<speed>.{$DuplexLength})"
            $PortStatusRxString += "(?<type>.+)"
            $Global:Test = $PortStatusRxString
            continue
        }

        if ($KeepGoing) {
            # interface <interface>
            $EvalParams.Regex = [regex] $PortStatusRxString
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $NewPort = [Port]::new(($Eval.Groups['name'].Value).Trim())
                $NewPort.OperStatus = ($Eval.Groups['oper'].Value).Trim()
                $NewPort.Duplex = ($Eval.Groups['duplex'].Value).Trim()
                $NewPort.Speed = ($Eval.Groups['speed'].Value).Trim()
                $NewPort.Type = ($Eval.Groups['type'].Value).Trim()
                $ReturnArray += $NewPort
                continue
            }

            # next prompt string
            $EvalParams.Regex = [regex] "^[^\s]+(>|#)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break :fileloop
            }
        }
    }
    return $ReturnArray
}