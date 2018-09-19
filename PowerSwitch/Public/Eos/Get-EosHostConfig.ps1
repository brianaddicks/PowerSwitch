function Get-EosHostConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-EosHostConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup Return Object
    $ReturnObjectProps = @()
    $ReturnObjectProps += "MgmtInterface"
    $ReturnObjectProps += "IpAddress"
    $ReturnObjectProps += "Name"
    $ReturnObjectProps += "Prompt"
    $ReturnObjectProps += "Location"

    $ReturnObject = "" | Select-Object $ReturnObjectProps

    function CheckIfFinished() {
        $NotDone = $true
        foreach ($prop in $ReturnObjectProps) {
            if ($null -eq $ReturnObject.$prop) {
                $NotDone = $false
            }
        }
        Write-Verbose "$VerbosePrefix`: $i`: CheckIfFinished: $NotDone"
        return $NotDone
    }

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

        #############################################
        # Universal Commands

        # set system name "<name>"
        $EvalParams.Regex = [regex] "^set\ system\ name\ `"(.+)`""
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Name = $Eval
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # set prompt "<prompt>"
        $EvalParams.Regex = [regex] '^set\ prompt\ "?([^"]+)"?'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Prompt = $Eval
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # set system location "<location>"
        $EvalParams.Regex = [regex] '^set\ system\ location\ "(.+)"'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Location = $Eval
            if (CheckIfFinished) { break fileloop }
            continue
        }

        #############################################
        # SecureStack Commands

        # host vlan
        $EvalParams.Regex = [regex] "^set\ host\ vlan\ (\d+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.MgmtInterface = "vlan.0.$Eval"
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # set ip address <ip> mask <mask> gateway <gateway>
        $EvalParams.Regex = [regex] "^set\ ip\ address\ (?<ip>$IpRx)\ mask\ (?<mask>$IpRx)\ gateway\ (?<gateway>$IpRx)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            $ReturnObject.IpAddress = $Eval.Groups['ip'].Value + '/' + (ConvertTo-MaskLength $Eval.Groups['mask'].Value)
            if (CheckIfFinished) { break fileloop }
            continue
        }

        #############################################
        # Core Series (S/K) Commands

        # set ip interface <ipinterface> default
        $EvalParams.Regex = [regex] "^set\ ip\ interface\ ([^\ ]+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.MgmtInterface = $Eval
            $ReturnObject.IpAddress = (Get-EosIpInterface -ConfigPath $ConfigPath -Name $ReturnObject.MgmtInterface).IpAddress[0]
            if (CheckIfFinished) { break fileloop }
            continue
        }


    }
    return $ReturnObject
}