function Get-EosAaaConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosAaaConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }
    Write-Verbose "$VerbosePrefix $ConfigPath"

    # Setup return Array
    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
    $ReturnObject = [AaaConfig]::new()

    $TotalLines = $LoopArray.Count
    Write-Verbose "$VerbosePrefix $TotalLines"
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

        $EvalParams.Regex = [regex] "^#\ *radius"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: radius: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            #set radius "(enable/disable)"
            $EvalParams.Regex = [regex] "^set\ radius\ (?<type>enable|disable)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Type = $Eval.Groups['type'].Value
                Write-Verbose "$VerbosePrefix $i`: radius: '$Type'"
                switch ($Type) {
                    'enable' {
                        $ReturnObject.RadiusEnabled = $True
                    }
                    'disable' {
                        $ReturnObject.RadiusEnabled = $false
                    }
                }
                continue
            }

        }

        if ($KeepGoing) {
            #set radius server "priority" "server ip" "port" :"pre-shared key":
            $EvalParams.Regex = [regex] "^set\ radius\ server\ (?<priority>.+?)\ (?<ip>$IpRx)\ (?<port>.+)\ :(?<preshare>.+):"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Priority = $Eval.Groups['priority'].Value
                $IP = $Eval.Groups['ip'].Value
                $Port = $Eval.Groups['port'].Value
                $PreShare = $Eval.Groups['preshare'].Value
                Write-Verbose "$VerbosePrefix $i`: radius: server '$IP' port '$Port' priority '$Priority' preshare '$PreShare'"
                $NewAuthServer = [AuthServer]::new()
                if ($Type -eq "enable") {
                    $NewAuthServer.NetLogon = $True
                    $NewAuthServer.ManagementLogon = $True
                }
                $NewAuthServer.ServerIP = $IP
                $NewAuthServer.Priority = $Priority
                $NewAuthServer.ServerPort = $Port
                $NewAuthServer.PreSharedKey = $PreShare
                $ReturnObject.AuthServer += $NewAuthServer
                continue
            }

        }
        # next config section
        $EvalParams.Regex = [regex] "^(!)\ "
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            break fileloop
        }

    }
    return $ReturnObject
}