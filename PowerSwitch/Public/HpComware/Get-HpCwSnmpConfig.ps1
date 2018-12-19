function Get-HpCwSnmpConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-HpCwSnmpConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup Return Object
    $ReturnObject = @{}
    $ReturnObject.Community = @()
    $ReturnObject.AllowedHost = @()
    $ReturnObject.Trap = @()
    $ReturnObject.Source

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

        #############################################
        # Universal Commands

        # snmp-agent community <access> <community>  acl <acl-number>
        $EvalParams.Regex = [regex] '^\ snmp-agent\ community\ (?<access>.+?)\ (?<community>[^\ ]+)'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $new = "" | Select-Object Community, Version, Access
            $new.Community = $Eval.Groups['community'].Value
            $new.Access = $Eval.Groups['access'].Value
            $new.Version = 'v2'
            $ReturnObject.Community += $new
            continue
        }

        # snmp-agent target-host trap address udp-domain <server> params securityname <community> <version>
        $EvalParams.Regex = [regex] '^\ snmp-agent\ target-host\ trap\ address\ udp-domain\ (?<target>.+?)\ params\ securityname\ (?<community>.+?)\ (?<version>.+)'
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $new = "" | Select-Object Target, Community, Version
            $new.Community = $Eval.Groups['community'].Value
            $new.Target = $Eval.Groups['target'].Value
            $new.Version = $Eval.Groups['version'].Value
            $ReturnObject.Trap += $new
            continue
        }

        # snmp-agent trap source <source>
        $EvalParams.Regex = [regex] '^\ snmp-agent trap source (.+)'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Source = $Eval
            continue
        }
    }

    return $ReturnObject
}