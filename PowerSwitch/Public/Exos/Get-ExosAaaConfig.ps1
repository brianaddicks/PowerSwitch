function Get-ExosAaaConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosAaaConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
    $ReturnObject = [AaaConfig]::new()
    $LocalAccount = [LocalAccount]::new()
    $LocalAccount.Name = 'admin'
    $LocalAccount.Type = 'admin'
    $ReturnObject.Account += $LocalAccount

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down

    # The following Rx will be ignored
    $IgnoreRx = @(
        'configure\ account\ admin'
        '^#$'
    )

    :fileloop foreach ($entry in $LoopArray) {
        $i++

        # Write progress bar, we're only updating every 1000ms, if we do it every line it takes forever

        if ($StopWatch.Elapsed.TotalMilliseconds -ge 1000) {
            $PercentComplete = [math]::truncate($i / $TotalLines * 100)
            Write-Progress -Activity "$VerbosePrefix Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
            $StopWatch.Reset()
            $StopWatch.Start()
        }

        if ($entry -eq "") { continue }

        ###########################################################################################
        # Check for the Section

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry

        $EvalParams.Regex = [regex] "^#\ Module\ aaa\ configuration"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: aaa: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # configure radius <accesstype> <priority> server <server> <port> client-ip <clientip> vr <vr>
            $EvalParams.Regex = [regex] '^configure\ radius\ (?<accesstype>.+?)\ (?<priority>.+?)\ server\ (?<server>.+?)\ (?<port>\d+)\ client-ip\ (?<clientip>.+?)\ vr\ (?<vr>.+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = [AuthServer]::new()
                $New.ServerIp = $Eval.Groups['server'].Value
                $New.Priority = $Eval.Groups['priority'].Value
                $New.ServerPort = $Eval.Groups['port'].Value

                switch ($Eval.Groups['accesstype'].Value) {
                    'mgmt-access' {
                        $New.ManagementLogon = $true
                    }
                    'netlogin' {
                        $New.NetLogon = $true
                    }
                }

                $ReturnObject.AuthServer += $New
                continue
            }

            # configure radius <accesstype> <priority> shared-secret encrypted "<secret>"
            $EvalParams.Regex = [regex] '^configure\ radius\ (?<accesstype>mgmt-access|netlogin)\ (?<priority>.+?)\ shared-secret encrypted "(?<secret>.+?)"'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Lookup = $ReturnObject.AuthServer | Where-Object { $_.Priority -eq $Eval.Groups['priority'].Value }
                $Lookup.PreSharedKey = $Eval.Groups['secret'].Value
                continue
            }

            # enable radius <type>
            $EvalParams.Regex = [regex] '^enable\ radius\ (mgmt-access|netlogin)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $ReturnObject.RadiusEnabled = $true
                continue
            }

            # create account <type> <name>
            $EvalParams.Regex = [regex] '^create\ account\ (?<type>.+?)\ (?<name>.+?)\ '
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = [LocalAccount]::new()
                $New.Name = $Eval.Groups['name'].Value
                $New.Type = $Eval.Groups['type'].Value
                $ReturnObject.Account += $New
                continue
            }

            # ignored lines
            foreach ($Rx in $IgnoreRx) {
                $EvalParams.Regex = [regex] $Rx
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    continue fileloop
                }
            }

            # lines not processed
            Write-Verbose "$VerbosePrefix $i`: $entry"

            # next config section
            $EvalParams.Regex = [regex] "^(#)\ "
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break fileloop
            }
        }
    }
    return $ReturnObject
}