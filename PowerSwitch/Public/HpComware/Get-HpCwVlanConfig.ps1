function Get-HpCwVlanConfig {
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
    $VerbosePrefix = "Get-HpCwVlanConfig:"

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

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry
        $EvalParams.LineNumber = $i

        # vlan create
        $EvalParams.Regex = [regex] "^vlan\ (.+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: vlan found $Eval"
            if ($Eval -match 'to') {
                $Start = [int]($Eval.Split()[0])
                $Stop = [int]($Eval.Split()[2])
                for ($i = $Start; $i -le $Stop; $i++) {
                    $NewVlan = [Vlan]::new($i)
                    $ReturnArray += $NewVlan
                }
            } else {
                $NewVlan = [Vlan]::new($Eval)
                $ReturnArray += $NewVlan
                $VlanKeepGoing = $true
            }
            continue
        }

        if ($VlanKeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry
            $EvalParams.LineNumber = $i

            # vlan name
            $EvalParams.Regex = [regex] '\ +name\ (.+)'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix`: Vlan $($NewVlan.Id): Name: $Eval"
                $NewVlan.Name = $Eval
                continue
            }

            # exit #
            $EvalParams.Regex = [regex] '^#$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix exiting vlan: $($NewVlan.Id)"
                $VlanKeepGoing = $false
                continue
            }
        }

        # interface create
        $EvalParams.Regex = [regex] "^interface\ (.+)"
        $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
        if ($Eval) {
            $InterfaceName = $Eval
            $InterfaceKeepGoing = $true
        }

        # interface config
        if ($InterfaceKeepGoing) {
            # exit #
            $EvalParams.Regex = [regex] '^#$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix exiting interface: $InterfaceName"
                $InterfaceKeepGoing = $false
                $IsTrunk = $false
                continue
            }

            # access vlan
            $EvalParams.Regex = [regex] "^\ +port\ access\ vlan\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $Lookup = $ReturnArray | Where-Object { $_.Id -eq [int]$Eval }
                $Lookup.UntaggedPorts += $InterfaceName
            }

            # check for trunk
            $EvalParams.Regex = [regex] "^\ +port\ link-type\ trunk"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $IsTrunk = $true
            }

            # trunk vlans
            $EvalParams.Regex = [regex] "^\ +port\ trunk\ permit\ vlan\ (.+)"
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $VlanRx = [regex]"((?<start>\d+)\ to\ (?<stop>\d+)|(?<vlan>\d+))"
                if ($IsTrunk) {
                    switch ($Eval) {
                        'all' {
                            $TaggedVlans = $ReturnArray.Id
                        }
                        default {
                            $VlanMatches = $VlanRx.Matches($Eval)
                            $TaggedVlans = @()
                            foreach ($match in $VlanMatches) {
                                if ($match.Value -match 'to') {
                                    $Start = ($match.Value).Split()[0]
                                    $Stop = ($match.Value).Split()[2]
                                    for ($i = [int]$Start; $i -le [int]$Stop; $i++) {
                                        $TaggedVlans += $i
                                    }
                                } else {
                                    $TaggedVlans += [int]$match.Value
                                }
                            }
                        }
                    }
                    foreach ($tag in $TaggedVlans) {
                        $Lookup = $ReturnArray | Where-Object { $_.Id -eq [int]$tag }
                        if ($Lookup) {
                            Write-Verbose "$VerbosePrefix $($Lookup.Id)"
                            $Lookup.TaggedPorts += $InterfaceName
                        } else {
                            Write-Verbose "$VerbosePrefix cannot find vlan $tag"
                        }
                    }
                }
            }

        }





    }
    return $ReturnArray
}