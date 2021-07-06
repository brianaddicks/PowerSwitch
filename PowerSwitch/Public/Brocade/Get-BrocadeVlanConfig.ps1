function Get-BrocadeVlanConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-BrocadeVlanConfig:"

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
    $ReturnArray += [Vlan]::new(1)
    $ReturnArray[0].Name = "Default Vlan"

    $Ports = Get-BrocadePortName -ConfigArray $LoopArray
    $ReturnArray[0].UntaggedPorts = ($Ports | Where-Object { $_.type -ne "other" }).Name

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

        # vlan create
        $EvalParams.Regex = [regex] "^vlan\ (?<id>\d+)(\ name\ (?<name>.+?)\ )?"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: vlan: create"
            $ExistingVlan = $ReturnArray | Where-Object { $_.Id -eq [int]$Eval.Groups['id'].Value }
            if ($ExistingVlan) {
                $ExistingVlan.Name = $Eval.Groups['name'].Value
            } else {
                $New = [Vlan]::new([int]$Eval.Groups['id'].Value)
                $New.Name = $Eval.Groups['name'].Value
                $ReturnArray += $New
            }
            $KeepGoingVlan = $true
            continue
        }

        if ($KeepGoingVlan) {

            # tagged ports
            # tagged ethe 1/1/1 to 1/1/30 ethe 1/3/1 ethe 2/1/1 to 2/1/30 ethe 2/3/1 ethe 3/1/1 to 3/1/48
            # trunk ethe 1/3/1 ethe 2/3/1

            $EvalParams.Regex = [regex] "^\ tagged\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: vlan: tagged ports: $Eval"
                $New.TaggedPorts += Resolve-PortString -PortString $Eval -SwitchType 'Brocade'
                continue
            }


            $Regex = [regex] '^!'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                $KeepGoingVlan = $false
                continue
            }
        }

        # interface config
        $EvalParams.Regex = [regex] "^interface\ (ethernet\ .+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: interface"
            $ThisInterface = $Eval
            $KeepGoingInterface = $true
            continue
        }

        if ($KeepGoingInterface) {

            # dual-mode

            $EvalParams.Regex = [regex] "^\ dual-mode\ +(.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $DefaultVlan = $ReturnArray | Where-Object { $_.Id -eq 1 }
                $DefaultVlan.UntaggedPorts = $DefaultVlan.UntaggedPorts | Where-Object { $_ -ne $ThisInterface }
                $ThisVlan = $ReturnArray | Where-Object { $_.Id -eq $Eval }
                if ($ThisVlan) {
                    $ThisVlan.UntaggedPorts += $ThisInterface
                    $ThisVlan.TaggedPorts = $ThisVlan.TaggedPorts | Where-Object { $_ -ne $ThisInterface }
                } else {
                    Write-Warning "$VerbosePrefix $i`: Unable to find vlan with Id: $Eval"
                }
                continue
            }


            $Regex = [regex] '^!'
            $Match = Get-RegexMatch $Regex $entry
            if ($Match) {
                $KeepGoingInterface = $false
                continue
            }
        }
    }
    return $ReturnArray
}