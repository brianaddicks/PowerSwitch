function Get-EosPortStatus {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosPortStatus:"

    # Check for path and import
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

        $Regex = [regex] '(?x)
                          ^(?<port>-+?)
                          \ (?<alias>-+?)
                          \ (?<oper>-+?)
                          \ (?<admin>-+?)
                          \ (?<speed>-+?)
                          \ (?<duplex>-+?)
                          \ (?<type>-+)'
        $Eval = Get-RegexMatch $Regex $entry
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: port status: output started"
            $KeepGoing = $true

            $PortLength = ($Eval.Groups['port'].Value).Length
            $AliasLength = ($Eval.Groups['alias'].Value).Length
            $OperLength = ($Eval.Groups['oper'].Value).Length
            $AdminLength = ($Eval.Groups['admin'].Value).Length
            $SpeedLength = ($Eval.Groups['speed'].Value).Length
            $DuplexLength = ($Eval.Groups['duplex'].Value).Length
            $TypeLength = ($Eval.Groups['type'].Value).Length

            $PortStatusRxString = "(?<name>.{$PortLength})"
            $PortStatusRxString += "\ (?<alias>.{$AliasLength})"
            $PortStatusRxString += "\ (?<oper>.{$OperLength})"
            $PortStatusRxString += "\ (?<admin>.{$AdminLength})"
            $PortStatusRxString += "\ (?<speed>.{$SpeedLength})"
            $PortStatusRxString += "\ (?<duplex>.{$DuplexLength})"
            $PortStatusRxString += "\ (?<type>.{1,$TypeLength})"

            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # port status line
            $EvalParams.Regex = [regex] $PortStatusRxString
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Name = ($Eval.Groups['name'].Value).Trim()
                $Type = ($Eval.Groups['type'].Value).Trim()
                Write-Verbose "$VerbosePrefix $i`: port status: adding port $Name"

                $NewPort = [Port]::new($Name, $Type)
                $NewPort.OperStatus = ($Eval.Groups['oper'].Value).Trim()
                $NewPort.AdminStatus = ($Eval.Groups['admin'].Value).Trim()
                $NewPort.Speed = ($Eval.Groups['speed'].Value).Trim()
                $NewPort.Duplex = ($Eval.Groups['duplex'].Value).Trim()

                $ReturnArray += $NewPort
            }

            if ($entry -notmatch "^\w+\.\d+\.\d+") {
                break
            }
        }
    }
    if ($ReturnArray.Count -eq 0) {
        Throw "$VerbosePrefix No Port Status found, requires output from 'show port status'"
    } else {
        return $ReturnArray
    }
}