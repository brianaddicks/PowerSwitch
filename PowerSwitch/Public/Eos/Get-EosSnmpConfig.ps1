function Get-EosSnmpConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosSnmpConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup ReturnObject
    $ReturnObject = @{}
    $ReturnObject.Access = @()
    $ReturnObject.Community = @()
    $ReturnObject.Group = @()
    $ReturnObject.Notify = @()
    $ReturnObject.TargetAddr = @()
    $ReturnObject.TargetParams = @()
    $ReturnObject.User = @()
    $ReturnObject.View = @()

    ############################################
    # Add default config

    #######################
    # Access
    $new = "" | Select-Object Name, SecModel
    $new.Name = 'ro'
    $new.SecModel = 'v1'
    $ReturnObject.Access += $new

    $new = "" | Select-Object Name, SecModel
    $new.Name = 'ro'
    $new.SecModel = 'v2c'
    $ReturnObject.Access += $new

    $new = "" | Select-Object Name, SecModel
    $new.Name = 'public'
    $new.SecModel = 'v1'
    $ReturnObject.Access += $new

    $new = "" | Select-Object Name, SecModel
    $new.Name = 'public'
    $new.SecModel = 'v2c'
    $ReturnObject.Access += $new

    $new = "" | Select-Object Name, SecModel
    $new.Name = 'public'
    $new.SecModel = 'usm'
    $ReturnObject.Access += $new

    #######################
    # Groups
    $new = "" | Select-Object Name, Member, SecModel
    $new.Name = 'ro'
    $new.Member = 'ro'
    $new.SecModel = @('v1', 'v2c')
    $ReturnObject.Group += $new

    $new = "" | Select-Object Name, Member, SecModel
    $new.Name = 'public'
    $new.Member = 'public'
    $new.SecModel = @('v1', 'v2c')
    $ReturnObject.Group += $new

    #######################
    # Users
    $new = "" | Select-Object Name, Authentication, Encryption
    $new.Name = 'public'
    $ReturnObject.User += $new

    #######################
    # Community
    $ReturnObject.Community += 'public'

    ########################################################################################
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
        # snmp
        $EvalParams = @{}
        $EvalParams.StringToEval = $entry

        $EvalParams.Regex = [regex] '^#(\ )?snmp'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: snmp: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry

            # snmp access
            $EvalParams.Regex = [regex] "^(?<action>clear|set)\ snmp\ access\ (?<user>[^\ ]+?)\ security-model\ (?<version>[^\ ]+)(\ privacy)?(\ exact)?(\ read\ (?<readview>[^\ ]+))?"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: snmp: access entry"

                $Action = $Eval.Groups['action'].Value
                $User = $Eval.Groups['user'].Value
                $SecModel = $Eval.Groups['version'].Value
                $ReadView = $Eval.Groups['readview'].Value

                if ($Action -eq 'clear') {
                    $Lookup = $ReturnObject.Access | Where-Object { ($_.Name -eq $User ) -and ( $_.SecModel -eq $SecModel) }
                    $ReturnObject.Access = $ReturnObject.Access | Where-Object { $_ -ne $Lookup }
                }

                continue
            }

            $Regex = [regex] '^!'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                Write-Verbose "$VerbosePrefix $i`: snmp: config ended"
                break
            }
        }
    }
    return $ReturnObject
}