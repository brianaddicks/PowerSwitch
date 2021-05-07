function Get-ExosEapsConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosEapsConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $ReturnObject = @{
        'Enabled' = $false
        'Domain'  = @()
    }

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

        $EvalParams.Regex = [regex] "^#\ Module\ eaps\ configuration"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: eaps: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams.Regex = [regex] '^enable\ eaps$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: eaps: enabled"
                $ReturnObject.Enabled = $true
                continue
            }

            # configure eaps <domain> mode <mode>
            $EvalParams.Regex = [regex] "^configure\ eaps\ (?<domain>.+?)\ mode\ (?<mode>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Domain = $Eval.Groups['domain'].Value
                $Mode = $Eval.Groups['mode'].Value
                Write-Verbose "$VerbosePrefix $i`: eaps: domain '$Domain' mode: $Mode"
                $DomainLookup = $ReturnObject.Domain | Where-Object { $_.Name -eq $Domain }
                $DomainLookup.Mode = $Mode
                continue
            }

            # configure eaps wan-eaps <primary|secondary> port <port-number>
            $EvalParams.Regex = [regex] "^configure\ eaps\ (?<domain>.+?)\ (?<type>primary|secondary)\ port\ (?<portnumber>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Domain = $Eval.Groups['domain'].Value
                $Type = $Eval.Groups['type'].Value
                $PortNumber = $Eval.Groups['portnumber'].Value
                Write-Verbose "$VerbosePrefix $i`: eaps: domain '$Domain': $Type port: $PortNumber"
                $DomainLookup = $ReturnObject.Domain | Where-Object { $_.Name -eq $Domain }
                switch ($Type) {
                    'primary' {
                        $DomainLookup.PrimaryPort = $PortNumber
                    }
                    'secondary' {
                        $DomainLookup.SecondaryPort = $PortNumber
                    }
                }
                continue
            }

            # configure eaps <domain> add <protected|control> vlan <vlan>
            $EvalParams.Regex = [regex] "^configure\ eaps\ (?<domain>.+?)\ add\ (?<type>protected|control)\ vlan\ (?<vlan>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $Domain = $Eval.Groups['domain'].Value
                $Type = $Eval.Groups['type'].Value
                $Vlan = $Eval.Groups['vlan'].Value
                Write-Verbose "$VerbosePrefix $i`: eaps: domain '$Domain' $Type vlan: $Vlan"
                $DomainLookup = $ReturnObject.Domain | Where-Object { $_.Name -eq $Domain }
                $DomainLookup."$Type`Vlan" += $Vlan
                continue
            }

            # Regex that just return a single string
            $EvalParams.ReturnGroupNumber = 1

            # create eaps <domain>
            $EvalParams.Regex = [regex] "^create\ eaps\ (.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: eaps: new domain found: $Eval"
                $NewEapsDomain = "" | Select-Object 'Name', 'Enabled', 'Mode', 'PrimaryPort', 'SecondaryPort', 'ProtectedVlan', 'ControlVlan'
                $NewEapsDomain.Name = $Eval
                $NewEapsDomain.Enabled = $false
                $NewEapsDomain.ProtectedVlan = @()

                $ReturnObject.Domain += $NewEapsDomain
                continue
            }

            # enable eaps <domain>
            $EvalParams.Regex = [regex] "^enable\ eaps\ (.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $DomainLookup = $ReturnObject.Domain | Where-Object { $_.Name -eq $Eval }
                $DomainLookup.Enabled = $true
                Write-Verbose "$VerbosePrefix $i`: eaps: domain '$Eval': Enabled"
                continue
            }

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