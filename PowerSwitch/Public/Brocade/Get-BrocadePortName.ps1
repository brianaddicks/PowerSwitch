function Get-BrocadePortName {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray,

        [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $True)]
        [array]$Ports
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-BrocadePortName:"

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

    if ($Ports) {
        $ReturnArray[0].UntaggedPorts = ($Ports | Where-Object { $_.type -ne "other" }).Name
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
        $EvalParams = @{ }
        $EvalParams.StringToEval = $entry

        $Regex = [regex] "^module\ (?<num>\d+)\ (?<bladetype>fi-sx\d?)-(?<count>\d+)-port-(?<speed>.+?)-(?<porttype>.+)(-(?<poe>poe))?-module"
        $Match = Get-RegexMatch $Regex $entry
        if ($Match) {
            Write-Verbose "$VerbosePrefix $i`: module: config started"
            $KeepGoing = $true
        }

        $EvalParams.Regex = [regex] "^stack\ unit\ (\d+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $StackNumber = $Eval
            Write-Verbose "$VerbosePrefix $i`: stack: $StackNumber config started"
            $KeepGoing = $true
        }

        if ($KeepGoing) {
            $EvalParams = @{ }
            $EvalParams.StringToEval = $entry

            # module decode
            # module 1 fi-sx6-8-port-10gig-fiber-module
            # module 1 fi-sx6-48-port-gig-copper-poe-module
            # module 1 fi-sx6-24-port-1gig-fiber-module
            # module 1 fi-sx-0-port-management-module
            # module 1fi-sx6-xl-0-port-management-module

            # stack module
            # stack unit 1
            #   module 1 icx6610-48p-poe-port-management-module
            #   module 2 icx6610-qsfp-10-port-160g-module
            #   module 3 icx6610-8-port-10g-dual-mode-module

            if ($StackNumber) {
                $EvalParams.Regex = [regex] "^\s*module\ (?<num>\d+)\ (?<bladetype>icx\d+)-((?<count>\d+)(?<porttype>p)-poe|(?<porttype>qsfp)-\d+|(?<count>\d+))-port-(?<speed>.+?)-"
            } else {
                $EvalParams.Regex = [regex] "^\s*module\ (?<num>\d+)\ (?<bladetype>fi-sx\d?)-(?<count>\d+)-port-(?<speed>.+?)-(?<porttype>.+)(-(?<poe>poe))?-module"
            }
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $BladeNumber = $Eval.Groups['num'].Value
                Write-Verbose "$VerbosePrefix $i`: module: decoding blade: $BladeNumber"
                $BladeType = $Eval.Groups['bladetype'].Value
                $PortSpeed = $Eval.Groups['speed'].Value
                $PortType = $Eval.Groups['porttype'].Value
                $PortCount = [int]$Eval.Groups['count'].Value
                $PortPoe = $Eval.Groups['poe'].Value

                Write-Verbose "$VerbosePrefix $i`: module: decoding blade: BladeType: $BladeType"
                Write-Verbose "$VerbosePrefix $i`: module: decoding blade: PortSpeed: $PortSpeed"
                Write-Verbose "$VerbosePrefix $i`: module: decoding blade: PortType: $PortType"

                if (($PortType -eq 'qsfp') -and ($PortSpeed -eq '160g')) {
                    Write-Verbose "$VerbosePrefix $i`: module: decoding blade: adjusting for 4x40gig"
                    $PortCount = 4
                    $PortSpeed = '40gig'
                }

                if ($PortSpeed -eq 'management') {
                    $PortSpeed = '1gig'
                }

                for ($portnum = 1; $portnum -le $PortCount; $portnum++) {
                    if ($StackNumber) {
                        $PortName = "ethernet " + $StackNumber + '/' + $BladeNumber + '/' + $portnum
                    } else {
                        $PortName = "ethernet " + $BladeNumber + '/' + $portnum
                    }
                    $New = [Port]::new($PortName, $PortType)
                    $New.OperStatus = 'Up'
                    $New.AdminStatus = 'Up'
                    $New.Speed = $PortSpeed
                    $New.Type = $PortType
                    $ReturnArray += $New
                }
            }

            $Regex = [regex] '^!'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                if ($StackNumber) {
                    Remove-Variable -Name StackNumber
                }
                break
            }
        }
    }

    return $ReturnArray
}