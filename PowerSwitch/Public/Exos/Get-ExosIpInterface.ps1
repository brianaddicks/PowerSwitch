function Get-ExosIpInterface {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosIpInterface:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
    $ReturnArray = @()
    $ReturnArray1 = @()
    $ReturnArray1 += [IpInterface]::new(1)
    $ReturnArray1[0].Name = "Default"
    $VlanConfig= Get-ExosVlanConfig -ConfigArray $LoopArray
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
        $EvalParams1 = @{}
        $EvalParams1.StringToEval = $entry

        $EvalParams1.Regex = [regex] "^#\ Module\ vlan\ configuration"
        $Eval1 = Get-RegexMatch @EvalParams
        if ($Eval1) {
            Write-Verbose "$VerbosePrefix $i`: bootprelay: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # configure vlan "(vlan name)" ipaddress "(ipaddress) (mask)" 
            $EvalParams.Regex = [regex] "^configure\ vlan\ (?<vlanname>.+?)\ ipaddress (?<ip>$IpRx)\ (?<mask>$IpRx)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $VlanName = $Eval.Groups['vlanname'].Value
                $IP = $Eval.Groups['ip'].Value
                $MaskIPV4Math = $Eval.Groups['mask'].Value
                $Mask = ConvertTo-MaskLength $MaskIPV4Math
                Write-Verbose "$VerbosePrefix $i`: vlan: name '$VlanName' ip '$IP/$Mask'"
                $New = [IpInterface]::new($VlanName)
                $ReturnArray += $New
                $IpInterfaceLookup = $ReturnArray | Where-Object { $_.Name -eq $VlanName }
                $IpInterfaceLookup.IpAddress = "$IP/$Mask"
                $IpInterfaceLookup.Enabled = $True
                $VlanConfigLookup = $VlanConfig | Where-Object { $_.Name -eq $VlanName }
                $IpInterfaceLookup.VlanId = $VlanConfigLookup.Id
                $IpInterfaceLookup.Description = $VlanConfigLookup.Description
                continue
            }
            $EvalParams.Regex = [regex] "^(?<type>enable|disable)\ (?<ipforward>ipforwarding|ipmcforwarding)\ vlan\ (?<vlanname>.+)"
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $VlanName = $Eval.Groups['vlanname'].Value
                $Type = $Eval.Groups['type'].Value
                $Ipforward = $Eval.Groups['ipforward'].Value
                Write-Verbose "$VerbosePrefix $i`: vlan: name '$VlanName' forwarding '$Ipforward' '$Type'"
                $IpInterfaceLookup = $ReturnArray | Where-Object { $_.Name -eq $VlanName }
                switch ($Type) {
                    'enable' { 
                        switch ($Ipforward) {
                            'ipforwarding' { 
                                $IpInterfaceLookup.IpForwardingEnabled = $True
                             }
                            'ipmcforwarding' {
                                $IpInterfaceLookup.IpMulticastForwardingEnabled = $True
                            }
                        }
                     }
                    'disable' {
                        switch ($Ipforward) {
                            'ipforwarding' { 
                                $IpInterfaceLookup.IpForwardingEnabled = $false
                             }
                            'ipmcforwarding' {
                                $IpInterfaceLookup.IpMulticastForwardingEnabled = $false
                            }
                        }
                    }
                }
                continue
            }

            $EvalParams1.Regex = [regex] "^configure\ bootprelay\ add\ (?<ip>$IpRx)\ vr\ (?<vr>.+)"
            $Eval1 = Get-RegexMatch @EvalParams1
            if ($Eval1){
                $IP = $Eval1.Groups['ip'].Value
                Write-Verbose "$VerbosePrefix $i`: Adding default bootprealy ip to seprate table '$IP'"
                $IpInterfaceLookup = $ReturnArray1 | Where-Object { $_.Name -eq "Default" }
                $IpInterfaceLookup.IpAddress += "$IP"
                continue
            }
             # configure vlan "(vlan name)" ipaddress "(ipaddress) (mask)" 
             $EvalParams1.Regex = [regex] "^enable\ bootprelay\ ipv4\ vlan\ (?<vlanname>.+)"
             $Eval1 = Get-RegexMatch @EvalParams1
             if ($Eval1) {
                 $VlanName = $Eval1.Groups['vlanname'].Value
                 Write-Verbose "$VerbosePrefix $i`: bootprelay on enabled on vlan: name '$VlanName'"
                 $IpInterfaceLookup = $ReturnArray | Where-Object { $_.Name -eq $VlanName }
                 $IpInterfaceLookup.IpHelperEnabled = $True
             }

             # configure bootprelay vlan (vlan name) add (ipaddress)
             $EvalParams1.Regex = [regex] "^configure\ bootprelay\ vlan\ (?<vlanname>.+?)\ add\ (?<ip>$IpRx)"
             $Eval1 = Get-RegexMatch @EvalParams1
             if ($Eval1){
                $VlanName = $Eval1.Groups['vlanname'].Value
                $IP = $Eval1.Groups['ip'].Value
                Write-Verbose "$VerbosePrefix $i`: bootprelay on enabled on vlan: name '$VlanName' Ipaddress '$IP'"
                $IpInterfaceLookup = $ReturnArray | Where-Object { $_.Name -eq $VlanName }
                 $IpInterfaceLookup.IpHelper += $IP
                continue
             }
             # next config section
             $EvalParams.Regex = [regex] "^(#)\ "
             $Eval = Get-RegexMatch @EvalParams
             $Eval1 = Get-RegexMatch @EvalParams1
             if ($Eval -and $Eval1) {
                 break fileloop
             }
        }
    }
    $DefaultIpInterfaceLookup = $ReturnArray1 | Where-Object { $_.Name -eq "Default" }
        $MissingIpHelpers = $ReturnArray| Where-Object { $_.IpHelperEnabled -eq $True -and $_.IpHelper -eq $null}
        foreach ($ip in $MissingIpHelpers) {
            $ip.IpHelper = $DefaultIpInterfaceLookup.IpAddress
        }

    return $ReturnArray
}