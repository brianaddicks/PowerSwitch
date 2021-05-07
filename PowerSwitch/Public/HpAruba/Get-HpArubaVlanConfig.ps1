function Get-HpArubaVlanConfig {
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
    $VerbosePrefix = "Get-HpArubaVlanConfig:"

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
    $ReturnArray[0].Name = "DEFAULT_VLAN"

    if ($Ports) {
        $ReturnArray[0].UntaggedPorts = ($Ports | Where-Object { $_.type -ne "other" }).Name
    }

    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down

    function ResolvePortString ($portString) {
        $ThisReturnArray = @()
        $PortNameRx = [regex] '(\d+)\/(\d+)'
        $CommaSplit = $portString.Split(',')
        foreach ($c in $CommaSplit) {
            $DashSplit = $c.Split('-')
            if ($DashSplit.Count -eq 2) {
                $StartPort = $DashSplit[0]
                $StopPort = $DashSplit[1]
                $StackMember = $PortNameRx.Match($StartPort).Groups[1].Value
                $StartPort = [int]($PortNameRx.Match($StartPort).Groups[2].Value)
                $StopPort = [int]($PortNameRx.Match($StopPort).Groups[2].Value)
                for ($i = $StartPort; $i -le $StopPort; $i++) {
                    $ThisReturnArray += "$StackMember/$i"
                }
            } else {
                $ThisReturnArray += $c
            }
        }
        $ThisReturnArray
    }

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
        $EvalParams.ReturnGroupNumber = 1
        $EvalParams.LineNumber = $i

        # vlan create
        $EvalParams.Regex = [regex] "^vlan\ (.+)"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: vlan found $Eval"
            $NewVlan = [Vlan]::new($Eval)
            $ReturnArray += $NewVlan
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            $EvalParams = @{}
            $EvalParams.StringToEval = $entry
            $EvalParams.LineNumber = $i

            # tagged/untagged single line
            $EvalParams.Regex = [regex] "^\ +(?<tagging>(un)?tagged)\ (?<portstring>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: ports found"
                if ($PortString) {
                    switch ($Tagging) {
                        'tagged' {
                            $NewVlan.TaggedPorts = ResolvePortString $PortString
                        }
                        'untagged' {
                            $NewVlan.UntaggedPorts = ResolvePortString $PortString
                        }
                    }
                }
                $Tagging = $Eval.Groups['tagging'].Value
                $ResolvedPorts = ResolvePortString $Eval.Groups['portstring'].Value
                switch ($Tagging) {
                    'tagged' {
                        $NewVlan.TaggedPorts = $ResolvedPorts
                    }
                    'untagged' {
                        $NewVlan.UntaggedPorts = $ResolvedPorts
                    }
                }
                continue
            }

            # tagged/untagged multi line
            $EvalParams.Regex = [regex] '^\ +(?<tagging>(un)?tagged)$'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix $i`: ports found"
                if ($PortString) {
                    switch ($Tagging) {
                        'tagged' {
                            $NewVlan.TaggedPorts = ResolvePortString $PortString
                        }
                        'untagged' {
                            $NewVlan.UntaggedPorts = ResolvePortString $PortString
                        }
                    }
                }
                $Tagging = $Eval.Groups['tagging'].Value
                $MultiLinePort = $true
                continue
            }

            if ($MultiLinePort) {
                # tagged/untagged single line
                $EvalParams.Regex = [regex] "^\s*(\d+.+)"
                $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
                if ($Eval) {
                    if ($PortString) {
                        $PortString += $Eval
                    } else {
                        $PortString = $Eval
                    }
                    Write-Verbose $PortString
                    continue
                }
            }

            # vlan name
            $EvalParams.Regex = [regex] '\ +name\ "(.+?)"'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                Write-Verbose "$VerbosePrefix`: Vlan $($NewVlan.Id): Name: $Eval"
                $NewVlan.Name = $Eval
                continue
            }

            # exit
            $EvalParams.Regex = [regex] '\s+(exit)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                Write-Verbose "$VerbosePrefix exiting vlan: $($NewVlan.Id)"
                $MultiLinePort = $false
                $KeepGoing = $false
                continue
            }
        }
    }
    return $ReturnArray
}