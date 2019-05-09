function Get-ExosVlanConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosVlanConfig:"

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
    $ReturnArray[0].Name = "Default"

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

        $EvalParams.Regex = [regex] "^#\ Module\ vlan\ configuration"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: vlan: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # create vlan "(vlan-name)"
            $EvalParams.Regex = [regex] "^create\ vlan\ `"(?<vlanname>.+?)`""
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $VlanName = $Eval.Groups['vlanname'].Value
                Write-Verbose "$VerbosePrefix $i`: vlan: name '$VlanName'"
                $New = [Vlan]::new($VlanName)
                $ReturnArray += $New
                continue
            }

            # configure vlan tag
            $EvalParams.Regex = [regex] "^configure\ vlan\ `"?(?<vlanname>.+?)`"?\ tag\ (?<vlantag>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $VlanName = $Eval.Groups['vlanname'].Value
                $VlanTag = $Eval.Groups['vlantag'].Value
                Write-Verbose "$VerbosePrefix $i`: vlan: name '$VlanName' tag: $VlanTag"
                $VlanLookup = $ReturnArray | Where-Object { $_.Name -eq $VlanName }
                $VlanLookup.Id = $VlanTag
                continue
            }

            # adding ports to vlan
            $EvalParams.Regex = [regex] "^configure\ vlan\ `"?(?<vlanname>.+?)`"?\ add\ ports\ (?<portnumber>.+)\ (?<type>tagged|untagged)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $VlanName = $Eval.Groups['vlanname'].Value
                $PortNumber = $Eval.Groups['portnumber'].Value
                $Type = $Eval.Groups['type'].Value
                Write-Verbose "$VerbosePrefix $i`: vlan: name '$VlanName' port: $PortNumber type: $Type"
                $VlanLookup = $ReturnArray | Where-Object { $_.Name -eq $VlanName }
                switch ($Type) {
                    'tagged' {
                        $VlanLookup.TaggedPorts += Resolve-PortString -PortString $PortNumber -SwitchType 'Exos'
                    }
                    'untagged' {
                        $VlanLookup.UntaggedPorts += Resolve-PortString -PortString $PortNumber -SwitchType 'Exos'
                    }
                }
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

    return $ReturnArray
}