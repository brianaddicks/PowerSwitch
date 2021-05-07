function Get-ExosHostConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $True, Position = 1)]
        [string]$ManagementIpAddress
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosHostConfig:"

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
            Write-Progress -Activity "$VerbosePrefix Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
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

        # configure snmp sysName "<name>"
        $EvalParams.Regex = [regex] '^configure\ snmp\ sysName\ "?([^"]+)"?'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Name = $Eval
            $ReturnObject.Prompt = $Eval
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # configure snmp sysLocation "<location>"
        $EvalParams.Regex = [regex] '^configure\ snmp\ sysLocation\ "?([^"]+)"?'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Location = $Eval
            if (CheckIfFinished) { break fileloop }
            continue
        }
    }
    #############################################
    # Set Management IP Manually, not sure how else we could do this on exos
    $ReturnObject.IpAddress = $ManagementIpAddress

    return $ReturnObject
}