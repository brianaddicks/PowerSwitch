function Get-ExosSnmpConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosSnmpConfig:"

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
    $ReturnObject = [SnmpConfig]::new()

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

        $EvalParams.Regex = [regex] "^#\ Module\ snmpMaster\ configuration"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: snmpMaster: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # enable snmp access <version>
            $EvalParams.Regex = [regex] '^enable\ snmp\ access(\ (?<version>.+))?'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Switch ($Eval.Groups['version'].Value) {
                    'snmp-v1v2c' {
                        $ReturnObject.V2Enabled = $true
                        $ReturnObject.V1Enabled = $true
                    }
                    'snmpv3' {
                        $ReturnObject.V3Enabled = $true
                    }
                    '' {
                        $ReturnObject.Enabled = $true
                    }
                }
                continue
            }

            # configure snmpv3 add group "v1v2c_ro" user "v1v2c_ro" sec-model snmpv1
            $EvalParams.Regex = [regex] '^configure\ snmpv3\ add\ group\ "(?<name>.+?)"\ user\ "(?<user>.+?)"\ sec-model\ (?<version>.+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = [SnmpGroup]::new()
                $New.Name = $Eval.Groups['name'].Value
                $New.User = $Eval.Groups['user'].Value

                switch ($Eval.Groups['version'].Value) {
                    'snmpv1' {
                        $New.Version = 1
                    }
                    'snmpv2c' {
                        $New.Version = 2
                    }
                    'usm' {
                        $New.Version = 3
                    }
                }

                $ReturnObject.Group += $New
                continue
            }

            # configure snmpv3 engine-id <engineid>
            $EvalParams.Regex = [regex] '^configure\ snmpv3\ engine-id\ (.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $ReturnObject.EngineId = $Eval
                continue
            }

            # configure snmpv3 add user "<user>" engine-id <engine> authentication <authtype> auth-encrypted localized-key <encryptedkey>
            $EvalParams.Regex = [regex] '^configure\ snmpv3\ add\ user\ "(?<user>.+?)"\ engine-id(\ .+?\ authentication\ (?<authtype>.+?)\ auth-encrypted\ localized-key\ [^\ ]+)?'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = [SnmpUser]::new()
                $New.Name = $Eval.Groups['user'].Value
                $New.AuthType = $Eval.Groups['authtype'].Value
                $New.PrivType = $Eval.Groups['privtype'].Value

                $ReturnObject.User += $New
                continue
            }

            # configure snmpv3 add community "<community>" name "<name>" user "<user>"
            $EvalParams.Regex = [regex] '^configure\ snmpv3\ add\ community\ "(?<community>.+?)"(\ encrypted)?\ name\ "(?<name>.+?)"\ user\ "(?<user>.+)"'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $ReturnObject.Community += $Eval.Groups['community'].Value
                continue
            }

            <# [string]$Group
            [string]$ReadView
            [string]$WriteView
            [string]$NotifyView #>

            # configure snmpv3 add access "<group>" sec-model usm sec-level priv read-view "<readview>" write-view "<writeview>" notify-view "<notifyview>"
            $EvalParams.Regex = [regex] '^configure\ snmpv3\ add\ access\ "(?<group>.+?)"\ sec-model\ usm\ sec-level\ priv\ read-view\ "(?<readview>.+?)"\ write-view\ "(?<writeview>.+?)"\ notify-view\ "(?<notifyview>.+?)"'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = [SnmpAccess]::new()
                $New.Group = $Eval.Groups['group'].Value
                $New.ReadView = $Eval.Groups['readview'].Value
                $New.WriteView = $Eval.Groups['writeview'].Value
                $New.NotifyView = $Eval.Groups['notifyview'].Value

                $ReturnObject.Access += $New
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

            # next config section
            $EvalParams.Regex = [regex] "^(#)\ "
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break fileloop
            }

            # lines not processed
            Write-Verbose "$VerbosePrefix $i`: $entry"
        }
    }
    return $ReturnObject
}