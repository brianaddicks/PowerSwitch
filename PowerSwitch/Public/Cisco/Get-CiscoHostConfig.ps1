function Get-CiscoHostConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-CiscoHostConfig:"

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
        $EvalParams.LineNumber = $i

        #############################################
        # Universal Commands

        # sysname <name>
        $EvalParams.Regex = [regex] '^hostname\ (.+)'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Name = $Eval
            $ReturnObject.Prompt = $Eval
            if (CheckIfFinished) { break fileloop }
            continue
        }

        # snmp-server location <location>
        $EvalParams.Regex = [regex] '^snmp-server\ location\ (.+)'
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $ReturnObject.Location = $Eval
            if (CheckIfFinished) { break fileloop }
            continue
        }
    }
    #############################################
    # Choose interface used for default gateway if no other option
    if (!($ReturnObject.IpAddress)) {
        $IpRoute = Get-CiscoStaticRoute -ConfigArray $LoopArray
        if ($IpRoute) {
            $IpInterface = Get-CiscoIpInterface -ConfigArray $LoopArray

            $DefaultRoute = $IpRoute | Where-Object { $_.Destination -eq '0.0.0.0/0' }
            Write-Verbose "$VerbosePrefix Lookup for NextHop: $($DefaultRoute.NextHop)"
            :interface foreach ($interface in $IpInterface) {
                Write-Verbose "$VerbosePrefix Checking: $($interface.Name)"
                foreach ($ip in $interface.IpAddress) {
                    Write-Verbose "$VerbosePrefix ip: $ip"
                    if (Test-IpInRange -ContainingNetwork $ip -IPAddress $DefaultRoute.NextHop) {
                        $ReturnObject.IpAddress = $ip
                        $ReturnObject.MgmtInterface = $interface.Name
                        break interface
                    }
                }
            }
        }
    }

    return $ReturnObject
}