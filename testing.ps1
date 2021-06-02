[CmdletBinding()]
Param (
    <# [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
    [string]$ConfigPath,

    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
    [array]$ConfigArray #>
)
ipmo ./PowerSwitch -Force -Verbose:$false


function Resolve-NewPortName {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [string]$PortName,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateRange(1,8)]
        [int]$NewSlot
    )

    $EdgePortRx = [regex] 'GigabitEthernet(?<slot>\d+)(\/0)?\/(?<port>\d+)'
    $EdgeMatch = $EdgePortRx.Match($PortName)
    if ($EdgeMatch.Success) {
        if ($NewSlot) {
            $NewName = [string]$NewSlot + ':' + $EdgeMatch.Groups['port'].Value
        } else {
            $NewName = $EdgeMatch.Groups['slot'].Value + ':' + $EdgeMatch.Groups['port'].Value
        }
    } else {
        Throw "Not an EdgePort: $PortName"
    }

    $NewName
}


# ---------- GCSS

$SnmpContact = 'rodney.thomason@gcssk12.net'
$NtpServers = @(
    '10.1.90.151'
    '10.1.90.152'
)
$DnsSuffixes = @(
    'gcssk12.its'
)

$DnsServers = $NtpServers

$EdgeSwitches = @(
    '10.8.2.2'
)

$Combine = $false

$IgnoredVlanIds = @(
    1
    1002
    1003
    1004
    1005
)


$InDir = '/Users/brianaddicks/Lockstep Technology Group/GCS - Gainesville City Schools - Documents/Projects/1083 - Switching Refresh E-Rate R2/Discovery/logs'
$Outdir = '/Users/brianaddicks/Lockstep Technology Group/GCS - Gainesville City Schools - Documents/Projects/1083 - Switching Refresh E-Rate R2/NewConfigs'
#$Outdir = '/Users/brianaddicks/Downloads'
$i = 0

$FullOutput = @()
$Header = @()
$VlanCreate = @()

$VlanConfig = @()
$PortConfig = @()
$PortStatus = @()
$Inventory = @()
$PoeModule = @()
#$SwitchSlots = $Inventory | Where-Object { $_.Slot -match '^\d+$' } | Select-Object Slot,Model -Unique
#$HostConfig = Get-CiscoHostConfig -ConfigArray $ConfigArray

$SingleSwitchPortRx = [regex] '^(?<type>Gi(gabitEthernet)?)0\/(?<port>\d+)'

if ($Combine) {
    foreach ($ThisSwitch in $EdgeSwitches) {
        $i++

        $FileLookup = Get-ChildItem -Path $InDir -Filter "*$ThisSwitch.log"
        switch ($FileLookup.Count) {
            1 {
                break
            }
            0 {
                Throw "No file found: $ThisSwitch"
            }
            default {
                Throw "$($FileLookup.Count) files found"
            }
        }
        $ConfigArray = gc $FileLookup

        # VlanConfig
        $ThisVlanConfig = Get-CiscoVlanConfig -ConfigArray $ConfigArray
        foreach ($vlan in $ThisVlanConfig) {
            if ($IgnoredVlanIds -contains $vlan.Id) {
                continue
            } else {
                $NewVlanConfig = $VlanConfig | Where-Object { $_.Id -eq $vlan.Id}
                if (-not $NewVlanConfig) {
                    $NewVlanConfig = New-PsVlanConfig -VlanId $vlan.Id
                    $NewVlanConfig.Name = $vlan.Name
                    $VlanConfig += $NewVlanConfig
                }
                # update port numbers
                foreach ($port in $vlan.UntaggedPorts) {
                    $SingleSwitchPortMatch = $SingleSwitchPortRx.Match($port)
                    if ($SingleSwitchPortMatch.Success) {
                        $NewPort = $SingleSwitchPortMatch.Groups['type'].Value + [string]$i + '/0/' + $SingleSwitchPortMatch.Groups['port'].Value
                        $NewVlanConfig.UntaggedPorts += $NewPort
                    } else {
                        Write-Warning "Could not match port: $port"
                    }
                }

                foreach ($port in $vlan.TaggedPorts) {
                    $SingleSwitchPortMatch = $SingleSwitchPortRx.Match($port)
                    if ($SingleSwitchPortMatch.Success) {
                        $NewPort = $SingleSwitchPortMatch.Groups['type'].Value + [string]$i + '/0/' + $SingleSwitchPortMatch.Groups['port'].Value
                        $NewVlanConfig.TaggedPorts += $NewPort
                    } else {
                        Write-Warning "Could not match port: $port"
                    }
                }
            }
        }

        # PortConfig
        $ThisPortConfig = Get-CiscoPortConfig -ConfigArray $ConfigArray
        foreach ($port in $ThisPortConfig) {
            $SingleSwitchPortMatch = $SingleSwitchPortRx.Match($port.Name)
            if ($SingleSwitchPortMatch.Success) {
                $NewPortName = $SingleSwitchPortMatch.Groups['type'].Value + [string]$i + '/0/' + $SingleSwitchPortMatch.Groups['port'].Value
                $port.Name = $NewPortName
                $PortConfig += $port
            } else {
                Write-Warning "Could not match port: $($port.Name)"
            }
        }

        # PortStatus
        $ThisPortStatus = Get-CiscoPortStatus -ConfigArray $ConfigArray
        foreach ($port in $ThisPortStatus) {
            $SingleSwitchPortMatch = $SingleSwitchPortRx.Match($port.Name)
            if ($SingleSwitchPortMatch.Success) {
                $NewPortName = $SingleSwitchPortMatch.Groups['type'].Value + [string]$i + '/0/' + $SingleSwitchPortMatch.Groups['port'].Value
                $port.Name = $NewPortName
                $PortStatus += $port
            } else {
                Write-Warning "Could not match port: $($port.Name)"
            }
        }

        # Inventory
        $ThisInventory = Get-CiscoInventory -ConfigArray $ConfigArray | Where-Object { $_.Slot -match '^\d+$' }
        if ($ThisInventory.Count -eq 1) {
            $ThisInventory.Slot = $i

            $Inventory += $ThisInventory
        } else {
            Write-Warning "Inventory is greater than 1: $ThisSwitch`: $($ThisInventory.Count)"
            return
        }

        $ThisPoeModule = Get-CiscoPoeModule -ConfigArray $ConfigArray
        if ($ThisPoeModule.Count -eq 1) {
            $PoeModule += $i
        }

        if ($i -eq 1 ) {
            $HostConfig = Get-CiscoHostConfig -ConfigArray $ConfigArray
            $BaseName = $FileLookup.BaseName
            $StaticRoute = Get-CiscoStaticRoute -ConfigArray $ConfigArray
            $DefaultRoute = $StaticRoute | Where-Object { $_.Destination -eq '0.0.0.0/0' }
            $IpInterface = Get-CiscoIpInterface -ConfigArray $ConfigArray
            $MgmtIpInterface = $IpInterface | Where-Object { Test-IpInRange -ContainingNetwork $_.IpAddress[0] -IPAddress ($HostConfig.IpAddress -replace '\/\d+') }
            $OutputFile = (Join-Path -Path $Outdir -ChildPath $($FileLookup.Name))
        }
        <#
        $SwitchSlots = $Inventory | Where-Object { $_.Slot -match '^\d+$' } | Select-Object Slot,Model -Unique
        $HostConfig = Get-CiscoHostConfig -ConfigArray $ConfigArray #>
    }
}

if ($Combine) {
    $EdgeSwitches = $EdgeSwitches[0]
}

$i = 0
foreach ($ThisSwitch in $EdgeSwitches) {
    $i++
    "$i/$($EdgeSwitches.Count)"

    $FullOutput = @()

    if (-not $Combine) {
        $FileLookup = Get-ChildItem -Path $InDir -Filter "*$ThisSwitch.log"
        switch ($FileLookup.Count) {
            1 {
                break
            }
            0 {
                Throw "No file found"
            }
            default {
                Throw "$($FileLookup.Count) files found"
            }
        }

        $OutputFile = (Join-Path -Path $Outdir -ChildPath $($FileLookup.Name))
        if (Test-Path -Path $OutputFile) {
            "Output complete, skipping $ThisSwitch"
            #continue
        }

        $ConfigArray = gc $FileLookup
        $BaseName = $FileLookup.BaseName
        $VlanConfig = Get-CiscoVlanConfig -ConfigArray $ConfigArray
        $PortConfig = Get-CiscoPortConfig -ConfigArray $ConfigArray
        $PortStatus = Get-CiscoPortStatus -ConfigArray $ConfigArray
        $Inventory = Get-CiscoInventory -ConfigArray $ConfigArray
        $PoeModule = Get-CiscoPoeModule -ConfigArray $ConfigArray
        $HostConfig = Get-CiscoHostConfig -ConfigArray $ConfigArray
        $StaticRoute = Get-CiscoStaticRoute -ConfigArray $ConfigArray
        $DefaultRoute = $StaticRoute | Where-Object { $_.Destination -eq '0.0.0.0/0' }
        $IpInterface = Get-CiscoIpInterface -ConfigArray $ConfigArray
        $MgmtIpInterface = $IpInterface | Where-Object { Test-IpInRange -ContainingNetwork $_.IpAddress[0] -IPAddress ($HostConfig.IpAddress -replace '\/\d+') }
    }
    $SwitchSlots = $Inventory | Where-Object { $_.Slot -match '^\d+$' } | Select-Object Slot,Model -Unique

    foreach ($slot in $SwitchSlots) {
        $ThisOutput = '# ' + $slot.Slot + ' ' + $slot.Model
        if ($PoeModule -contains $slot.Slot) {
            $ThisOutput += ' !!!! POE !!!!'
        }
        $FullOutput += $ThisOutput
    }

    #Export-PsPortMap -Path (Join-Path -Path $Outdir -ChildPath "$BaseName`.xlsx") -PortConfig $PortConfig -DeviceName $BaseName -PortStatus $PortStatus

    #region sanitizeVlans
    #################################################################################

    $ValidVlans = $VlanConfig | Where-Object { $IgnoredVlanIds -notcontains $_.Id }
    foreach ($vlan in $ValidVlans) {
        $vlanName = ($vlan.Name -replace "\.","").ToLower()
        $vlanName = ($vlanName -replace "\/","-").ToLower()
        if ($vlanName -eq 'security') {
            $vlanName = 'security-vlan'
        }
        if ($vlanName -eq 'mgmt') {
            $vlanName = 'device-mgmt'
        }
        $vlan.Name = $vlanName
    }

    #################################################################################
    #region sanitizeVlans

    #region getImportantVlans
    #################################################################################

    $VoiceVlanId = $PortConfig.VoiceVlan | Where-Object { $_ -ne 0 } | Select-Object -Unique
    $VoiceVlan = $ValidVlans | Where-Object { $_.Id -eq $VoiceVlanId }
    $EdgeVlan = ($ValidVlans | Select-Object Name,@{ Name = 'UntaggedCount';Expression = { $_.UntaggedPorts.Count } } | Sort-Object UntaggedCount | Select-Object -Last 1).Name

    #################################################################################
    #endregion getImportantVlans

    #region translatePorts
    #################################################################################

    if ($SwitchSlots.Count -eq 1) {
        $EdgePortRx = [regex] 'GigabitEthernet(?<slot>\d+)(\/0)?\/(?<port>\d+)'
    } else {
        $EdgePortRx = [regex] 'GigabitEthernet(?<slot>\d+)\/0\/(?<port>\d+)'
    }
    $EdgePorts = $PortConfig | Where-Object { $_.Name -match $EdgePortRx }

    if (-not $EdgePorts.Count) {
        Throw "No edge ports found"
    }

    foreach ($vlan in $ValidVlans) {
        $NewPortList = @()
        foreach ($port in $vlan.Untaggedports) {
            $EdgePortMatch = $EdgePortRx.Match($port)
            if ($EdgePortMatch.Success) {
                $NewPortName = $EdgePortMatch.Groups['slot'].Value + ':' + $EdgePortMatch.Groups['port'].Value
                $NewPortName = Resolve-NewPortName $port
                $NewPortList += $NewPortName
            }
        }
        $vlan.UntaggedPorts = $NewPortList

        $NewPortList = @()
        foreach ($port in $vlan.Taggedports) {
            $EdgePortMatch = $EdgePortRx.Match($port)
            if ($EdgePortMatch.Success) {
                $NewPortName = $EdgePortMatch.Groups['slot'].Value + ':' + $EdgePortMatch.Groups['port'].Value
                $NewPortName = Resolve-NewPortName $port
                $NewPortList += $NewPortName
            }
        }
        $vlan.TaggedPorts = $NewPortList
    }

    #################################################################################
    #endregion translatePorts


    $FullOutput += ''
    $FullOutput += '# default port config'

    #region defaultPort
    #################################################################################

    $FullOutput += 'disable cli prompting'
    $FullOutput += 'enable jumbo-frame ports all'
    $FullOutput += 'configure vlan default delete ports all'

    foreach ($slot in $SwitchSlots) {
        $FullOutput += 'configure vr VR-Default delete ports ' + $slot.Slot + ':1-54'
    }


    #################################################################################
    #endregion defaultPort

    #region createVlan
    #################################################################################

    $FullOutput += ''
    $FullOutput += '# create vlans, enable stp'

    foreach ($vlan in $ValidVlans) {
        $FullOutput += "create vlan """ + $vlan.Name + """ tag " + $vlan.Id
        $FullOutput += "enable stpd s0 auto-bind vlan " + $vlan.Name
    }

    #################################################################################
    #endregion createVlan

    #region configure port vlans
    #################################################################################

    $FullOutput += ''
    $FullOutput += '# port vlan assignment'

    # set all edge ports
    foreach ($slot in $SwitchSlots) {
        $FullOutput += 'configure vlan ' + $EdgeVlan + ' add port ' + $slot.Slot + ':1-48 untagged'
        if ($VoiceVlan.Count -eq 1) {
            $FullOutput += 'configure vlan ' + $VoiceVlan.Name + ' add port ' + $slot.Slot + ':1-48 tagged'
        } elseif ($VoiceVlan.Count -gt 1) {
            Throw "$($FileLookup.BaseName): $($VoiceVlan.Count) voice vlans detected"
        }
    }

    $FullOutput += ''
    foreach ($vlan in $ValidVlans) {
        if ($vlan.UntaggedPorts.Count -gt 0) {
            $UntaggedPortString = Resolve-ShortPortString $vlan.UntaggedPorts -SwitchType exos
            $FullOutput += 'configure vlan ' + $vlan.Name + ' add port ' + $UntaggedPortString + ' untagged'
        }

        if ($vlan.TaggedPorts.Count -gt 0) {
            $TaggedPortString = Resolve-ShortPortString $vlan.TaggedPorts -SwitchType exos
            $FullOutput += 'configure vlan ' + $vlan.Name + ' add port ' + $TaggedPortString + ' tagged'
        }
    }

    #################################################################################
    #endregion createVlan

    #region uplink
    #################################################################################

    if ($SwitchSlots.Count -ge 2) {
        $UplinkGrouping = '1:49,2:49'
    } else {
        $UplinkGrouping = '1:49,1:50'
    }

    $FullOutput += ''
    $FullOutput += '# uplink config'
    $FullOutput += 'enable sharing 1:49 grouping ' + $UplinkGrouping + ' algorithm address-based L2 lacp'
    $FullOutput += 'configure vlan ' + ($ValidVlans.Id -join ',') + ' add port 1:49 tagged'
    $FullOutput += 'configure port ' + $UplinkGrouping + ' display-string uplink'

    #################################################################################
    #endregion uplink

    #region stpedge
    #################################################################################

    $FullOutput += ''
    $FullOutput += '# stpedge'
    foreach ($slot in $SwitchSlots) {
        $FullOutput += 'configure stpd s0 ports edge-safeguard enable ' + $slot.Slot + ':1-48'
        $FullOutput += 'configure stpd s0 ports bpdu-restrict enable ' + $slot.Slot + ':1-48'
    }
    $FullOutput += 'enable stpd s0'

    #################################################################################
    #endregion stpedge

    #region portconfig
    #################################################################################

    $FullOutput += ''
    $FullOutput += '# port config'
    foreach ($port in $EdgePorts) {
        $EdgePortMatch = $EdgePortRx.Match($port.Name)
        $NewPortName = $EdgePortMatch.Groups['slot'].Value + ':' + $EdgePortMatch.Groups['port'].Value
        $NewPortName = Resolve-NewPortName $port.Name

        if ($port.Alias) {
            $NewAlias = $port.Alias.ToLower()
            $NewAlias = $NewAlias -replace ' ','-'
            $NewAlias = $NewAlias -replace '\/','' -replace '\(','' -replace "'",''
            if ($NewAlias.Length -gt 20) {
                $NewAlias = $NewAlias.SubString(0,20)
                $FullOutput += 'configure port ' + $NewPortName + ' description-string "' + $port.Alias.ToLower() + '"'
            }
            $FullOutput += 'configure port ' + $NewPortName + ' display-string ' + $NewAlias
        }

        if ($port.AdminStatus -ne 'up') {
            $FullOutput += 'disable port ' + $NewPortName
        }
    }

    #################################################################################
    #endregion portconfig

    #region dhcpsnooping
    #################################################################################

    $FullOutput += ''
    $FullOutput += '# dhcpedge'
    foreach ($vlan in $ValidVlans) {
        if ($vlan.UntaggedPorts.Count -gt 0) {
            $UntaggedPortString = Resolve-ShortPortString $vlan.UntaggedPorts -SwitchType exos
            $FullOutput += 'enable ip-security dhcp-snooping vlan ' + $vlan.Name + ' port ' + $UntaggedPortString + ' violation-action drop-packet block-mac permanently snmp-trap'
        }

        if ($vlan.TaggedPorts.Count -gt 0) {
            $TaggedPortString = Resolve-ShortPortString $vlan.TaggedPorts -SwitchType exos
            $FullOutput += 'enable ip-security dhcp-snooping vlan ' + $vlan.Name + ' port ' + $TaggedPortString + ' violation-action drop-packet block-mac permanently snmp-trap'
        }


        #$FullOutput += "enable ip-security dhcp-snooping vlan " + $vlan.Name + " port all violation-action drop-packet block-mac permanently snmp-trap"
    }
    $FullOutput += 'configure trusted-ports 1:49 trust-for dhcp-server'

    #################################################################################
    #endregion dhcpsnooping

    #region mgmtconfig
    #################################################################################

    $FullOutput += ''
    $FullOutput += '# mgmt'
    $FullOutput += 'configure snmp sysName "' + $HostConfig.Name + '"'
    $FullOutput += 'configure snmp sysContact "' + $SnmpContact + '"'
    $FullOutput += ''
    $FullOutput += 'disable telnet'
    $FullOutput += 'disable web http'
    $FullOutput += 'enable snmp access'
    $FullOutput += 'disable snmp access snmp-v1v2c'
    $FullOutput += 'enable snmp access snmpv3'
    $FullOutput += 'disable snmpv3 default-group'

    #################################################################################
    #endregion mgmtconfig

    #region aaa
    #################################################################################

    $FullOutput += ''
    $FullOutput += '# aaa'
    $FullOutput += 'configure account admin encrypted "$5$Spzgj/$H1Z8d/6HyHEIqabM1M0GcFbdeuuPpU9vtzFPkQD4LPD"'
    $FullOutput += 'create account admin lockstep encrypted "$5$/K0Ak/$fWxqRAAh21r9CTcm0rVwpS0RnijzvfeudQl5XBct0/1"'

    #################################################################################
    #endregion aaa




    #region ntpdns
    #################################################################################

    foreach ($ntpServer in $NtpServers) {
        $FullOutput += 'configure sntp-client primary ' + $ntpServer + ' vr VR-Default'
    }
    $FullOutput += 'enable sntp-client'
    $FullOutput += 'configure timezone name Eastern -300 autodst'

    $FullOutput += ''
    foreach ($dnsServer in $DnsServers) {
        $FullOutput += 'configure dns-client add name-server ' + $dnsServer + ' vr VR-Default'
    }

    foreach ($dnsSuffix in $DnsSuffixes) {
        $FullOutput += 'configure dns-client add domain-suffix ' + $dnsSuffix
    }

    #################################################################################
    #endregion ntpdns

    #region lldpcdp
    #################################################################################

    $FullOutput += ''
    $FullOutput += '# lldp and cdp'
    $FullOutput += 'enable cdp ports all'
    $FullOutput += 'configure lldp ports all advertise system-capabilities management-address'
    $FullOutput += 'configure lldp ports all advertise vendor-specific med capabilities'
    $FullOutput += 'configure lldp ports all advertise vendor-specific med power-via-mdi'

    if ($VoiceVlan.Count -eq 1) {
        $FullOutput += 'configure lldp port all advertise vendor-specific dot1 port-protocol-vlan-id vlan ' + $VoiceVlan.Name
        $FullOutput += 'configure lldp port all advertise vendor-specific dot1 vlan-name vlan ' + $VoiceVlan.Name
        $FullOutput += 'configure lldp port all advertise vendor-specific med policy application voice vlan ' + $VoiceVlan.Name + ' dscp 46'
    } elseif ($VoiceVlan.Count -gt 1) {
        Throw "$($FileLookup.BaseName): $($VoiceVlan.Count) voice vlans detected"
    }

    #################################################################################
    #region lldpcdp

    #region managementIp
    ############### ##################################################################



    $FullOutput += ''
    $FullOutput += '# mgmt ip'

    if ($DefaultRoute.Count -eq 1) {
        if ($MgmtIpInterface.Count -eq 1) {
        $FullOutput += 'configure vlan ' + $MgmtIpInterface.VlanId + ' ipaddress ' + $MgmtIpInterface.IpAddress
        $FullOutput += 'configure iproute add default ' + $DefaultRoute.NextHop
        } else {
            Throw "$($MgmtIpInterface.Count) mgmt IP interfaces found"
        }
    } else {
        Throw "$($DefaultRoute.Count) default routes found"
    }

    #################################################################################
    #region managementIp

    $FullOutput += 'enable ssh2'
    $FullOutput += 'save'

    $FullOutput | Out-File -FilePath $OutputFile
}

($Header + $FullOutput) | Out-File -FilePath $OutputFile

<#
$UniqueVlans = $Vlans | Select-Object Name,Id -Unique

$Output = @()
$DhcpOutput = @()

$IgnoredVlans = @(
    1
    1002
    1003
    1004
    1005
)

foreach ($vlan in $UniqueVlans) {
    $vlanName = ($vlan.Name -replace "\.","").ToLower()
    $vlanName = ($vlanName -replace "\/","-").ToLower()
    if ($vlanName -eq 'security') {
        $vlanName = 'security-vlan'
    }
    if ($vlanName -eq 'mgmt') {
        $vlanName = 'device-mgmt'
    }
    if ($IgnoredVlans -contains $vlan.Id) {
        continue
    }
    $Output += "create vlan """ + $vlanName + """ tag " + $vlan.Id
    $Output += "enable stpd s0 auto-bind vlan " + $vlanName
    $DhcpOutput += "enable ip-security dhcp-snooping vlan " + $vlanName + " port all violation-action drop-packet block-mac permanently snmp-trap"
} #>

#$Output

<# $port = Get-CiscoPortConfig -ConfigPath '/Users/brianaddicks/Downloads/defcoreold' -verbose

$NewConfig = @()
foreach ($p in $port) {
    $NameMatchRx = [regex] 'GigabitEthernet(\d+)\/0\/(\d+)'
    $NameMatch = $NameMatchRx.Match($p.Name)

    if ($NameMatch.Success) {
    $Blade = $NameMatch.Groups[1].Value
    $PortName = $NameMatch.Groups[2].Value
    $NewPort = [string]([int]$Blade + 2) + ':' + $PortName
        if ($p.Alias) {
            $NewConfig += 'configure port ' + $NewPort + ' display-string "' + $p.Alias + '"'
        }
        $NewConfig += 'configure vlan ' + $p.UntaggedVlan + ' add port ' + $NewPort + ' untagged'
        if ($p.TaggedVlan.Count -gt 0) {
            $TheseTaggedVlans = $p.TaggedVlan | ? { $_ -ne $p.UntaggedVlan }
            $NewConfig += 'configure vlan ' + ($TheseTaggedVlans -join ',') + ' add port ' + $NewPort + ' tagged'
        }
        if ($p.VoiceVlan -gt 0) {
            $NewConfig += 'configure vlan ' + ($p.VoiceVlan -join ',') + ' add port ' + $NewPort + ' tagged'
        }
    } else {
        continue
    }
}

$NewConfig += 'configure vlan 1 delete ports all' #>

<#
Name                    Mode   NativeVlan UntaggedVlan TaggedVlan                    VoiceVlan
----                    ----   ---------- ------------ ----------                    ---------
Port-channel1           trunk           1            1 1020|1052|1053|1060                   0
Port-channel2           trunk           1            1                                       0

 #>
<#
if ($ConfigPath) {
    if (Test-Path -Path $ConfigPath -PathType Leaf) {
        $ConfigFiles = gci $ConfigPath
    } elseif (Test-Path -Path $ConfigPath -PathType Container) {
        $ConfigFiles = gci $ConfigPath
    } else {
        Throw "Bad Path"
    }
}



$CiscoCommands = @(
    'terminal length 0'
    'show version'
    'show module'
    'show cdp neighbors detail'
    'show int status'
    'show ip route'
    'show etherchannel summary'
    'show spanning-tree'
    'show power inline'
    'show run'
    'exit'
)

# ignore neighbors
$IgnoreNeighborRemotePortRx = '^(eth|vmnic|Port\s|FastEthernet\d+\/)\d+$'

$i = 0
$ReturnObject = @()

if ($ConfigArray) {
    $CdpNeighbors = Get-CiscoCdpNeighbor -ConfigArray $ConfigArray
} else {
    foreach ($file in $ConfigFiles) {
        $DuplicateLog = $false
        $i++
        Write-Host "$i/$($ConfigFiles.Count)"

        $ConfigArray = gc $file

        $PowerSwitchParams = @{}
        $PowerSwitchParams.ConfigArray = $ConfigArray

        $NewSwitch = "" | Select-Object File,SwitchType,HostConfig,AllNeighbors,InterestingNeighbors,IpInterfaces
        $NewSwitch.File = $file.Name

        # get PsSwitchType, this will be used for all subsquent commands
        try {
            $ThisSwitchType = Get-PsSwitchType @PowerSwitchParams
        } catch {
            Write-Warning "Could not get PsSwitchType: $($file.Name)"
            continue
        }
        $NewSwitch.SwitchType = $ThisSwitchType
        $PowerSwitchParams.PsSwitchType = $ThisSwitchType

        # get host config and use it to look for duplicates
        $ThisHostConfig = Get-PsHostConfig @PowerSwitchParams -ErrorAction Stop
        $LookupHostConfig = $ReturnObject | Where-Object { $_.HostConfig.MgmtInterface -eq $ThisHostConfig.MgmtInterface -and $_.HostConfig.IpAddress -eq $ThisHostConfig.IpAddress -and $_.HostConfig.Name -eq $ThisHostConfig.Name}
        if ($LookupHostConfig) {
            Write-Warning "Duplicate found: `r`n oldfile: $($LookupHostConfig.file)`r`n newfile: $($file.Name)"
            $DuplicateLog = $true
        } else {
            $NewSwitch.HostConfig = $ThisHostConfig
        }

        # Neighbors
        if ($DuplicateLog) {
            $LookupHostConfig.AllNeighbors += Get-PsNeighbor @PowerSwitchParams
            $LookupHostConfig.AllNeighbors = $LookupHostConfig.AllNeighbors | Select-Object * -Unique
        } else {
            $NewSwitch.AllNeighbors = Get-PsNeighbor @PowerSwitchParams
        }

        # Ip Interfaces
        if ($DuplicateLog) {
            $LookupHostConfig.IpInterfaces += Get-PsIpInterface @PowerSwitchParams
            $LookupHostConfig.IpInterfaces = $LookupHostConfig.IpInterfaces | Select-Object * -Unique
        } else {
            $NewSwitch.IpInterfaces = Get-PsIpInterface @PowerSwitchParams
        }

        if (-not $DuplicateLog) {
            $ReturnObject += $NewSwitch
        }
    }
}

# get InterestingNeighbors, weeds out phones, esx, APs, etc
foreach ($NewSwitch in $ReturnObject) {
    $NewSwitch.InterestingNeighbors = $NewSwitch.AllNeighbors | Where-Object { $_.RemotePort -notmatch $IgnoreNeighborRemotePortRx }
}


$MissingNeighbors = @()

:neighbor foreach ($neighbor in $ReturnObject.InterestingNeighbors) {
    foreach ($NewSwitch in $ReturnObject) {
        foreach ($Interface in $NewSwitch.IpInterfaces) {
            foreach ($ThisIp in $Interface.IpAddress) {
                $JustThisIp = $ThisIp -replace '\/\d+',''
                if ($JustThisIp -eq $neighbor.IpAddress) {
                    continue neighbor
                }
            }
        }
    }
    $MissingNeighbors += $neighbor
}
 #>
#$ReturnObject = $ReturnObject | ? { $_.RemotePort -notmatch '^(eth|vmnic|Port\s|FastEthernet\d+\/)\d+$'}


<# $CdpNeighbors = Get-CiscoCdpNeighbor -ConfigArray $ConfigArray

$CdpNeighbors | ft LocalPort,RemotePort,DeviceId,IpAddress,DeviceDescription
 #>

<#
# FORSYTH

$InputDirectory = '/Users/brian/Lockstep Technology Group/FOR - Forsyth County Schools - Documents/Projects/951 - Core Network Assessment/CO Configs'
$OutputDirectory = '/Users/brian/Lockstep Technology Group/FOR - Forsyth County Schools - Documents/Projects/951 - Core Network Assessment/'
$OutputFile = Join-Path $OutputDirectory 'Device Details.xlsx'
$ConfigFiles = gci $InputDirectory -Exclude 'zzz*','*.xlsx','10.1.255.25.txt'
$ConfigFiles = $ConfigFiles | Group-ObjectByIpAddress -Property BaseName

$ReturnObject = @()

$NeighborTable = @()
$HostConfigTable = @()
$TimeConfigTable = @()
$PortConfigTable = @()
$AaaConfigTable = @()
$LocalAccountTable = @()
$ElrpConfigTable = @()
$ElrpVlanTable = @()
$LogConfigTable = @()
$SnmpConfigTable = @()
$SnmpUserTable = @()
$SnmpCommunityTable = @()
$MlagPeerTable = @()
$MlagPortTable = @()
$InventoryTable = @()

foreach ($file in $ConfigFiles) {
    Write-Warning $file.BaseName
    $ThisConfig = gc $file.FullName

    $HostConfig = Get-ExosHostConfig -ConfigArray $ThisConfig -ManagementIpAddress $file.BaseName
    $HostConfigTable += $HostConfig | Select-Object `
        @{ Name = 'LogFile'; Expression = { $file.Name } },
        IpAddress,Name,Prompt,Location

    $Inventory = Get-ExosInventory -ConfigArray $ThisConfig
    $InventoryTable += $Inventory | Select-Object `
        @{ Name = 'LogFile'; Expression = { $file.Name } },
        Slot,Model

    #region mlag
    $MlagConfig = Get-ExosMlagConfig -ConfigArray $ThisConfig

    foreach ($peer in $MlagConfig.Peer) {
        foreach ($address in $peer.PeerAddress) {
            $New = "" | Select LogFile,Peer,IpAddress,VirtualRouter,IsAlternate
            $New.LogFile = $file.Name
            $New.Peer = $peer.Name
            $New.IpAddress = $address.IpAddress
            $New.VirtualRouter = $address.VirtualRouter
            $New.IsAlternate = $address.IsAlternate

            $MlagPeerTable += $New
        }
    }

    foreach ($port in $MlagConfig.Port) {
        $New = "" | Select LogFile,Port,Peer,Id
        $New.LogFile = $file.Name
        $New.Port = $port.Port
        $New.Peer = $port.Peer
        $New.Id = $port.Id

        $MlagPortTable += $New
    }
    #endregion mlag

    $TimeConfig = Get-ExosTimeConfig -ConfigArray $ThisConfig
    $TimeConfigTable += $TimeConfig | Select-Object `
        @{ Name = 'LogFile'; Expression = { $file.Name } },
        @{ Name = 'SntpEnabled'; Expression = { $_.Enabled } },
        @{ Name = 'SntpServer'; Expression = { ($_.SntpServer | Sort-Object) -join ',' } },
        TimeZone,SummerTime*

    $PortConfig = Get-ExosPortConfig -ConfigArray $ThisConfig
    $PortConfigTable += $PortConfig | Select-Object `
        @{ Name = 'LogFile'; Expression = { $file.Name } },
        Name,Alias,OperStatus,AdminStatus,Speed,Duplex,NoNegotiate,
        Aggregate,AggregateAlgorithm,LacpEnabled,JumboEnabled,UntaggedVlan,
        @{ Name = 'TaggedVlan'; Expression = { ($_.TaggedVlan | Sort-Object) -join ',' } }


    $AaaConfig = Get-ExosAaaConfig -ConfigArray $ThisConfig
    $AaaConfigTable += $AaaConfig | Select-Object `
        @{ Name = 'LogFile'; Expression = { $file.Name } },
        RadiusEnabled,
        @{ Name = 'RadiusServerIp'; Expression = { ($_.AuthServer.ServerIP | Sort-Object) -join ',' } }

    $LocalAccountTable += $AaaConfig.Account | Select-Object `
        @{ Name = 'LogFile'; Expression = { $file.Name } },
        Name,Type

    $ElrpConfig = Get-ExosElrpConfig -ConfigArray $ThisConfig
    $VlanConfig = Get-ExosVlanConfig -ConfigArray $ThisConfig
    foreach ($vlan in $VlanConfig) {
        $New = "" | Select LogFile,VlanName,DisablePort,DisableDurationInSeconds,Log,Trap,Ingress,Port,IntervalInSeconds
        $New.LogFile = $file.Name
        $New.VlanName = $vlan.Name

        $ElrpLookup = $ElrpConfig.Vlan | ? { $_.VlanName -eq $vlan.Name }
        $New.DisablePort = $ElrpLookup.DisablePort
        $New.DisableDurationInSeconds = $ElrpLookup.DisableDurationInSeconds
        $New.Log = $ElrpLookup.Log
        $New.Trap = $ElrpLookup.Trap
        $New.Ingress = $ElrpLookup.Ingress
        $New.Port = $ElrpLookup.Port -join ','
        $New.IntervalInSeconds = $ElrpLookup.IntervalInSeconds

        $ElrpVlanTable += $New
    }

    $ElrpConfigTable += $ElrpConfig | Select-Object `
            @{ Name = 'LogFile'; Expression = { $file.Name } },
            Enabled,
            @{ Name = 'ExcludedPorts'; Expression = { ($_.ExcludedPorts | Sort-Object) -join ',' } }

    $LogConfig = Get-ExosLogConfig -ConfigArray $ThisConfig
    $New = "" | Select-Object LogFile,LogServers
    $New.LogFile = $file.Name
    $New.LogServers = $LogConfig -join ','
    $LogConfigTable += $New

    $SnmpConfig = Get-ExosSnmpConfig -ConfigArray $ThisConfig
    $SnmpConfigTable += $SnmpConfig | Select-Object `
            @{ Name = 'LogFile'; Expression = { $file.Name } },
            *Enabled

    foreach ($comm in $SnmpConfig.Community) {
        $New = "" | Select LogFile,Community
        $New.LogFile = $file.Name
        $New.Community = $comm
        $SnmpCommunityTable += $New
    }

    foreach ($user in $SnmpConfig.User) {
        $New = "" | Select LogFile,Name,AuthType,PrivType
        $New.LogFile = $file.Name
        $New.Name = $user.Name
        $New.AuthType = $user.AuthType
        $New.PrivType = $user.PrivType
        $SnmpUserTable += $New
    }

    #region neighbors
    $Neighbors = Get-ExosLldpNeighbor -ConfigArray $ThisConfig
    foreach ($neighbor in $Neighbors) {
        $new = "" | Select-Object Filename,LocalIpAddress,LocalDeviceName,LocalPort,RemoteIpAddress,RemoteDeviceName,RemotePort,PortType,Confirmed,Aggregate,MlagId,UntaggedVlan,TaggedVlan
        $new.Filename = $file.Name
        $new.LocalIpAddress = $file.BaseName
        $new.LocalDeviceName = $HostConfig.Name
        $new.LocalPort = $neighbor.LocalPort

        $new.RemoteIpAddress = $neighbor.IpAddress
        $new.RemotePort = $neighbor.RemotePort
        $new.RemoteDeviceName = $neighbor.DeviceName

        $Lookup = $NeighborTable | ? { $_.LocalDeviceName -eq $new.RemoteDeviceName -and $_.LocalPort -eq $new.RemotePort }
        if ($Lookup) {
            $Lookup.Confirmed = $true
            $new.Confirmed = $true
        }

        $PortLookup = $PortConfig | ? { $_.Name -eq $neighbor.LocalPort }
        if ($PortLookup) {
            $new.UntaggedVlan = $PortLookup.UntaggedVlan
            $new.TaggedVlan = ($PortLookup.TaggedVlan | Sort-Object) -join ','
            $new.Aggregate = $PortLookup.Aggregate
            $new.PortType = $PortLookup.Type
        }

        $MlagLookup = $MlagConfig.Port | ? { $_.Port -eq $neighbor.LocalPort }
        if ($MlagConfig) {
            $new.MlagId = $MlagLookup.Id
        }

        $NeighborTable += $new
    }

    if ($Neighbors.Count -eq 0) {
        $new = "" | Select-Object Filename,LocalIpAddress,LocalDeviceName,LocalPort,RemoteIpAddress,RemoteDeviceName,RemotePort,PortType,Confirmed,Aggregate,MlagId,UntaggedVlan,TaggedVlan
        $new.Filename = $file.Name
        $new.LocalIpAddress = $file.BaseName
        $new.LocalDeviceName = $HostConfig.Name
        $new.LocalPort = 'NO NEIGHBORS FOUND'

        $NeighborTable += $new
    }
    #endregion neighbors


}

<#
# HALL COUNTY

rm $OutputFile

$HostConfigTable | Export-Excel -Path $OutputFile -WorksheetName 'HostConfig' -ClearSheet -AutoSize -Activate
$NeighborTable | Export-Excel -Path $OutputFile -WorksheetName 'Neighbor' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$TimeConfigTable | Export-Excel -Path $OutputFile -WorksheetName 'Time' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$PortConfigTable | Export-Excel -Path $OutputFile -WorksheetName 'Port' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$AaaConfigTable | Export-Excel -Path $OutputFile -WorksheetName 'AAA' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$LocalAccountTable | Export-Excel -Path $OutputFile -WorksheetName 'LocalAccount' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$ElrpConfigTable | Export-Excel -Path $OutputFile -WorksheetName 'Elrp' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$ElrpVlanTable | Export-Excel -Path $OutputFile -WorksheetName 'ElrpVlan' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$LogConfigTable | Export-Excel -Path $OutputFile -WorksheetName 'Log' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$SnmpConfigTable | Export-Excel -Path $OutputFile -WorksheetName 'Snmp' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$SnmpUserTable | Export-Excel -Path $OutputFile -WorksheetName 'SnmpUser' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$SnmpCommunityTable | Export-Excel -Path $OutputFile -WorksheetName 'SnmpCommunity' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$MlagPeerTable | Export-Excel -Path $OutputFile -WorksheetName 'MlagPeer' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$MlagPortTable | Export-Excel -Path $OutputFile -WorksheetName 'MlagPort' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *
$InventoryTable | Export-Excel -Path $OutputFile -WorksheetName 'Inventory' -ClearSheet -AutoSize -FreezePane 2,2 -NoNumberConversion *

& $OutputFile

$Conf = '/Users/brian/Lockstep Technology Group/HCG - Hall County Government - Documents/Projects/971 - Emergency Network Consulting/Configs/192.168.101.1-ESCS4.log'
#$Conf = '/Users/brian/Lockstep Technology Group/HCG - Hall County Government - Documents/Projects/971 - Emergency Network Consulting/Configs/192.168.69.254-MISswitch.log'
$ConfigArray = gc $Conf
$PortStatus = Get-EosPortStatus -ConfigArray $ConfigArray
$VlanConfig = Get-EosVlanConfig -ConfigArray $ConfigArray
$PortAlias = Get-EosPortAlias -ConfigArray $ConfigArray -Verbose

$NewPorts = @()

foreach ($port in $PortStatus) {
    if ($port.Name -match '^(ge|tg|lag)\.') {
        if ($port.Name -match '^lag\.') {
            if ($port.OperStatus -eq 'down') {
                continue
            }
        }

        $TaggedVlanLookup = $VlanConfig | ? { $_.TaggedPorts -contains $port.Name }
        $UntaggedVlanLookup = $VlanConfig | ? { $_.UntaggedPorts -contains $port.Name }

        if ($TaggedVlanLookup) {
            foreach ($vlan in $TaggedVlanLookup) {
                $port.TaggedVlan += $vlan.Id
            }
        }

        if ($UntaggedVlanLookup) {
            if ($UntaggedVlanLookup.Count -gt 1) {
                Throw "too many untagged vlans"
            }
            $port.UntaggedVlan = $UntaggedVlanLookup.Id
            $port.NativeVlan = $UntaggedVlanLookup.Id
        }

        $AliasLookup = $PortAlias | ? { $_.Name -eq $port.Name }
        if ($AliasLookup) {
            $port.Alias = $AliasLookup.Alias
        }

        $NewPorts += $port
    }
}

$OutputDir = '/Users/brian/Lockstep Technology Group/HCG - Hall County Government - Documents/Projects/971 - Emergency Network Consulting'
$OutputFile = Join-Path -Path $OutputDir -ChildPath 'newconfig.xlsx'

$NewPorts | Select-Object @{ Name = 'OldDevice'; Expression = { 'MISswitch' } }, `
    @{ Name = 'OldPort'; Expression = { $_.Name } }, `
    NewDevice,NewPort,Alias,UntaggedVlan, `
    @{ Name = 'TaggedVlan'; Expression = { $_.TaggedVlan -join ',' } }, `
    OperStatus,AdminStatus,Lag | Export-Excel -Path $OutputFile -WorksheetName 'MISswitchPortMap' -ClearSheet -NoNumberConversion *

$NewVlanSummary = @()
$NewVlanConfig = @()
foreach ($vlan in $VlanConfig) {
    if ($vlan.TaggedPorts.Count -gt 0 -or $vlan.UntaggedPorts.Count -gt 0) {
        if ($null -eq $vlan.Name) {
            $NewName = "VLAN" + $vlan.id.ToString("0000")
        } else {
            $NewName = ($vlan.Name -replace ' ','-').ToLower()
        }
        $NewVlanConfig += "create vlan " + $NewName + " tag " + $vlan.Id
        $NewVlanSummary += $vlan | Select-Object Id,@{Name = 'Name'; e = {$NewName}}
    }
}
#>

<#
$OutputDir = '/Users/brian/Lockstep Technology Group/HCG - Hall County Government - Documents/Projects/971 - Emergency Network Consulting'

#$LldpNeighbors = Get-ExosLldpNeighbor -ConfigArray $ConfigArray
#$LldpNeighbors | select * -ExcludeProperty *Protocol,DeviceDescription | ft * -AutoSize

$ConfigPath = '/Users/brian/Lockstep Technology Group/HCG - Hall County Government - Documents/Projects/971 - Emergency Network Consulting/Configs/'
$ConfigFiles = gci $ConfigPath

$IpInterfaces = @()
foreach ($config in $ConfigFiles) {
    $ThisConfig = gc $config
    $IpInterface = Get-EosIpInterface -ConfigArray $ThisConfig
    $HostConfig = Get-EosHostConfig -ConfigArray $ThisConfig
    foreach ($interface in $IpInterface) {
        foreach ($ip in $interface.IpAddress) {
            $NewObject = "" | Select-Object File,MgmtIpAddress,Name,Prompt,Location,IpAddress,Network,Mask,Cidr
            $NewObject.File = $config.Name
            $NewObject.MgmtIpAddress = $HostConfig.IpAddress
            $NewObject.Name = $HostConfig.Name
            $NewObject.Prompt = $HostConfig.Prompt
            $NewObject.Location = $HostConfig.Location
            $NewObject.IpAddress = $ip

            $NetworkSummary = Get-NetworkSummary $ip

            $NewObject.Network = $NetworkSummary.Network
            $NewObject.Mask = $NetworkSummary.MaskLength
            $NewObject.Cidr = $NetworkSummary.Network + '/' + $NetworkSummary.MaskLength

            $IpInterfaces += $NewObject
        }
    }
}
 #>
<#
$NeighborFile = '/Users/brian/Lockstep Technology Group/HCG - Hall County Government - Documents/Projects/971 - Emergency Network Consulting/NetworkMapData.xlsx'
$Neighbors = Import-Excel $NeighborFile
$ValidNeighbors = $Neighbors | ? { $_.RemotePort }

$ReturnObject = @()

foreach ($neighbor in $ValidNeighbors) {
    $ThisConfigFile = $ConfigFiles | ? { $_.Name -match "$($neighbor.LocalIpAddress)-" }
    $ThisConfigArray = gc $ThisConfigFile
    $VlanConfig = Get-EosVlanConfig -ConfigArray $ThisConfigArray
    $UntaggedVlans = ($VlanConfig | ? { $_.UntaggedPorts -contains $neighbor.LocalPort }).Id
    $TaggedVlans = ($VlanConfig | ? { $_.TaggedPorts -contains $neighbor.LocalPort }).Id
    if ($UntaggedVlans.Count -gt 0) {
        $VlanString = "U" + ($UntaggedVlans -join ',')
    } else {
        $VlanString = ""
    }

    if ($TaggedVlans.Count -gt 0) {
        if ($VlanString -ne '') {
            $VlanString += ';'
        }
        $VlanString += 'T' + ($TaggedVlans -join ',')
    }

    $NewNeighbor = "" | Select LocalDevice,LocalIpAddress,LocalPort,RemotePort,RemoteIpAddress,VlanString
    $NewNeighbor.LocalDevice = $neighbor.LocalDevice
    $NewNeighbor.LocalIpAddress = $neighbor.LocalIpAddress
    $NewNeighbor.LocalPort = $neighbor.LocalPort
    $NewNeighbor.RemotePort = $neighbor.RemotePort
    $NewNeighbor.RemoteIpAddress = $neighbor.RemoteIpAddress
    $NewNeighbor.VlanString = $VlanString

    $ReturnObject += $NewNeighbor
}





$FullInventory = @()
$StpInfo = @()
foreach ($config in $ConfigFiles) {
    Write-Verbose $config.BaseName
    $ThisConfig = gc $config
    $HostConfig = Get-EosHostConfig -ConfigArray $ThisConfig

    # spantree
    $StpConfig = Get-EosSpantreeConfig -ConfigArray $ThisConfig
    $StpNewObject = Copy-PsObjectWithNewProperty -PsObject $HostConfig -NewProperty StpEnabled,StpMode,StpPriority,StpDisabledPorts
    $StpNewObject.StpEnabled = $StpConfig.StpEnabled
    $StpNewObject.StpMode = $StpConfig.StpMode
    $StpNewObject.StpPriority = $StpConfig.Priority
    $StpNewObject.StpDisabledPorts = $StpConfig.AdminDisabledPorts.Count

    $StpInfo += $StpNewObject

    # inventory
    $Inventory = Get-EosInventory -ConfigArray $ThisConfig
    if ($Inventory.Count -eq 0) {
        Write-Warning "No Inventory found for $($Config.BaseName)"
    }
    foreach ($item in $Inventory) {
        $NewObject = Copy-PsObjectWithNewProperty -PsObject $item -NewProperty File,IpAddress,Name,Prompt,Location
        $NewObject.File = $config.Name
        $NewObject.IpAddress = $HostConfig.IpAddress
        $NewObject.Name = $HostConfig.Name
        $NewObject.Prompt = $HostConfig.Prompt
        $NewObject.Location = $HostConfig.Location

        $NewObject.Slot = $item.Slot
        $NewObject.Module = $item.Module
        $NewObject.Model = $item.Model
        $NewObject.Serial = $item.Serial
        $NewObject.Firmware = $item.Firmware
        $NewObject.Status = $item.Status

        $FullInventory += $NewObject
    }
}

$InventoryOutputPath = Join-Path $OutputDir 'inventory.csv'
$FullInventory | Select IpAddress,File,Name,Prompt,Location,Slot,Module,Model,Firmware,Serial,Status | Export-Csv -Path $InventoryOutputPath -NoTypeInformation #>

 #>


<#
$HostConfig = Get-HpArubaHostConfig -ConfigArray $ConfigArray
$HostConfig.IPAddress = (gci $ConfigPath).BaseName

$Neighbors = Get-HpArubaNeighbor -ConfigArray $ConfigArray

$DesiredCapabilities = @('bridge','router')
$DesiredNeighbors = @()

:neighborloop foreach ($neighbor in $Neighbors) {
    foreach ($cap in $neighbor.CapabilitiesEnabled) {
        if ($DesiredCapabilities -notcontains $cap) {
            continue neighborloop
        }
    }
    if ($neighbor.DeviceDescription -match 'VMware ESX') {
        continue neighborloop
    }

    $DesiredNeighbors += $neighbor
}
 #>

<#
$ConfigDirectory = '/Users/brian/Lockstep Technology Group/EGA - East Georgia State College - Documents/Projects/922 - Extreme Swainsboro Switch Refresh/configs/*.cfg'
$ConfigFiles = Get-ChildItem -Path $ConfigDirectory

$SwitchTypes = @()

foreach ($config in $ConfigFiles) {
    $ConfigArray = Get-Content -Path $config
    $SwitchTypes += Get-PsSwitchType -ConfigArray $ConfigArray
}

$UniqueSwitchTypes = $SwitchTypes | Select-Object -Unique

$SwitchProperties = @{}
$SwitchProperties.ExtremeEos = @(
    'Hostname'
    'IpAddress'
    'DefaultGateway'
    'Location'
    'SwitchMember'
    'IgmpSnooping'
    'MacAuthentication'
    'RadiusEnabled'
    'RadiusAccountingServer'
    'RadiusServer'
    'SntpServer'
    'VlanConfig'
    'ForcedAuthPorts'
    'PortPolicy'
    'Lags'
    'PortAlias'
    'StpEdgePorts'
)

$DesiredProperties = @()
$DesiredProperties += 'ConfigFile'
foreach ($SwitchType in $UniqueSwitchTypes) {
    $DesiredProperties += $SwitchProperties.ExtremeEos
}

$EosSwitchTypes = @{
    '1' = 'C5G124-24'
    '2' = 'C5K125-24'
    '3' = 'C5K175-24'
    '4' = 'C5K125-24P2'
    '5' = 'C5G124-24P2'
    '6' = 'C5G124-48'
    '7' = 'C5K125-48'
    '8' = 'C5K125-48P2'
    '9' = 'C5G124-48P2'
}

$AggregateData = @()
foreach ($config in $ConfigFiles) {
    $ConfigArray = Get-Content -Path $config
    $new = "" | Select-Object $DesiredProperties
    $New.ForcedAuthPorts = @()
    $New.MacAuthentication = @()
    $New.PortPolicy = @()
    $New.Lags = @()
    $New.PortAlias = @()
    $New.StpEdgePorts = @()

    $AggregateData += $new

    $new.ConfigFile = $config.Name

    $MgmtConfig = Get-EosHostConfig -ConfigArray $ConfigArray
    $new.Hostname = $MgmtConfig.Name
    $new.IpAddress = $MgmtConfig.IpAddress
    $new.DefaultGateway = $MgmtConfig.DefaultGateway
    $new.Location = $MgmtConfig.Location

    $AaaConfig = Get-EosAaaConfig -ConfigArray $ConfigArray
    $new.RadiusEnabled = $AaaConfig.RadiusEnabled
    $new.RadiusServer = ($AaaConfig.AuthServer.ServerIp | Sort-Object) -join ','

    $TimeConfig = Get-EosTimeConfig -ConfigArray $ConfigArray
    $new.SntpServer = ($TimeConfig.SntpServer | Sort-Object) -join ','


    # stack inventory
    $new.SwitchMember = @()
    $Rx = [regex] '^set\ switch\ member\ (?<member>\d+)\ (?<type>\d+)'
    foreach ($line in $ConfigArray) {
        $Match = $Rx.Match($line)
        if ($Match.Success) {
            $SwitchTypeNumber = $Match.Groups['type'].Value
            $new.SwitchMember += $EosSwitchTypes.$SwitchTypeNumber
        }
    }
    $new.SwitchMember = $new.SwitchMember -join "`r`n"

    $Ports = Get-EosPortName -ConfigArray $ConfigArray
    $new.VlanConfig = Get-EosVlanConfig -ConfigArray $ConfigArray -Ports $Ports

    foreach ($vlan in $new.VlanConfig) {
        $NewPorts = @()
        foreach ($port in $vlan.TaggedPorts) {
            $NewPorts += $port -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'
        }
        $vlan.TaggedPorts = $NewPorts

        $NewPorts = @()
        foreach ($port in $vlan.UntaggedPorts) {
            $NewPorts += $port -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'
        }
        $vlan.UntaggedPorts = $NewPorts
    }

    $LagNames = @()

    foreach ($entry in $ConfigArray) {
        $Rx = [regex] 'set\ eapol\ auth-mode\ forced-auth\ (?<port>.+)'
        if ($Rx.Match($entry).Success) {
            $new.ForcedAuthPorts += $Rx.Match($entry).Groups['port'].Value -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'
        }

        $Rx = [regex] 'set\ multiauth\ port\ mode\ force-auth\ (?<port>.+)'
        if ($Rx.Match($entry).Success) {
            $new.ForcedAuthPorts += $Rx.Match($entry).Groups['port'].Value -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'
        }

        $Rx = [regex] 'set\ macauthentication\ port\s+enable\ (?<port>.+)'
        if ($Rx.Match($entry).Success) {
            $new.MacAuthentication += $Rx.Match($entry).Groups['port'].Value -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'
        }

        $Rx = [regex] 'set\ policy\ port\ (?<port>.+?)\ (?<policy>\d+)'
        if ($Rx.Match($entry).Success) {
            $PortPolicy = "" | Select Port,Policy
            $PortPolicy.Port = $Rx.Match($entry).Groups['port'].Value -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'
            $PortPolicy.Policy = $Rx.Match($entry).Groups['policy'].Value

            $new.PortPolicy += $PortPolicy
        }

        $Rx = [regex] 'set\ port\ lacp\ port\ (?<port>.+?)\ aadminkey\ (?<key>\d+)'
        if ($Rx.Match($entry).Success) {
            $Port = $Rx.Match($entry).Groups['port'].Value -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'
            $Key = $Rx.Match($entry).Groups['key'].Value

            $LagLookup = $new.Lags | ? { $_.Key -eq $Key }
            if ($LagLookup) {
                $LagLookup.Grouping += $Port
            } else {
                $NewLag = "" | Select-Object MasterPort,Grouping,Lacp,Key

                $NewLag.MasterPort = $Port
                $NewLag.Grouping = @($Port)
                $NewLag.Lacp = $false
                $NewLag.Key = $Key

                $new.Lags += $NewLag
            }
        }

        $Rx = [regex] 'set\ port\ lacp\ port\ (?<port>.+?)\ enable'
        if ($Rx.Match($entry).Success) {
            $Port = $Rx.Match($entry).Groups['port'].Value -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'

            $LagLookup = $new.Lags | ? { $_.Grouping -contains $Port }
            if ($LagLookup) {
                $LagLookup.Lacp = $true
            }
        }

        $Rx = [regex] 'set\ port\ alias\ (?<port>.+?)\ "?(?<alias>[^"]+)"?'
        if ($Rx.Match($entry).Success) {
            $PortAlias = "" | Select Port,Alias
            $PortAlias.Port = $Rx.Match($entry).Groups['port'].Value -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'
            $PortAlias.Alias = $Rx.Match($entry).Groups['alias'].Value

            $New.PortAlias += $PortAlias
        }

        $Rx = [regex] 'set\ spantree\ adminedge\ (?<port>.+?)\ true'
        if ($Rx.Match($entry).Success) {
            $New.StpEdgePorts += $Rx.Match($entry).Groups['port'].Value -replace 'ge\.(\d+)\.(\d+)','$1:$2' -replace 'tg\.(\d+)\.(49|25)','$1:51' -replace 'tg\.(\d+)\.(50|26)','$1:52'
        }

        $Rx = [regex] 'set\ lacp\ aadminkey\ (?<name>.+?)\ (?<key>\d+)'
        if ($Rx.Match($entry).Success) {
            $LagName = "" | Select Name,Key
            $LagName.Name = $Rx.Match($entry).Groups['name'].Value
            $LagName.Key = $Rx.Match($entry).Groups['key'].Value

            $LagNames += $LagName
        }
    }

    # resolve lags
    foreach ($lag in $LagNames) {
        $LagLookup = $new.Lags | ? { $_.Key -eq $lag.Key }
        foreach ($vlan in $new.VlanConfig) {
            $PortLookup = $vlan.UntaggedPorts | ? { $_ -eq $lag.Name }
            if ($PortLookup) {
                $vlan.UntaggedPorts += $LagLookup.MasterPort

                foreach ($port in ($LagLookup.Grouping | ? { $_ -ne $LagLookup.MasterPort })) {
                    $vlan.UntaggedPorts = $Vlan.UntaggedPorts | ? { $_ -ne $port }
                }
            }
            $vlan.UntaggedPorts = $vlan.UntaggedPorts | ? { $_ -ne $lag.Name } | Select-Object -Unique


            $PortLookup = $vlan.TaggedPorts | ? { $_ -eq $lag.Name }
            if ($PortLookup) {
                $vlan.TaggedPorts += $LagLookup.MasterPort

                foreach ($port in ($LagLookup.Grouping | ? { $_ -ne $LagLookup.MasterPort })) {
                    $vlan.TaggedPorts = $Vlan.TaggedPorts | ? { $_ -ne $port }
                }
            }
            $vlan.TaggedPorts = $vlan.TaggedPorts | ? { $_ -ne $lag.Name } | Select-Object -Unique
        }
    }

    # remove unused lags
    foreach ($vlan in $new.VlanConfig) {
        $vlan.UntaggedPorts = $vlan.UntaggedPorts | ? { $_ -notmatch 'lag\.0' }
        $vlan.TaggedPorts = $vlan.TaggedPorts | ? { $_ -notmatch 'lag\.0' }
    }

    $new.ForcedAuthPorts = $new.ForcedAuthPorts | Select-Object -Unique
}

$PolicyMap = @{}
$PolicyMap."1" = "1"
$PolicyMap."2" = "2"
$PolicyMap."4" = "3"
$PolicyMap."5" = "4"
$PolicyMap."7" = "5"
$PolicyMap."9" = "6"
$PolicyMap."10" = "7"
$PolicyMap."23" = "8"
$PolicyMap."11" = "9"
$PolicyMap."12" = "10"
$PolicyMap."13" = "11"
$PolicyMap."14" = "12"
$PolicyMap."3" = "13"
$PolicyMap."18" = "14"
$PolicyMap."25" = "15"
$PolicyMap."6" = "16"
$PolicyMap."8" = "17"
$PolicyMap."24" = "18"
$PolicyMap."15" = "19"
$PolicyMap."16" = "20"
$PolicyMap."17" = "21"
$PolicyMap."19" = "22"
$PolicyMap."20" = "23"
$PolicyMap."22" = "24"
$PolicyMap."21" = "25"

$OutputDirectory = '/Users/brian/Lockstep Technology Group/EGA - East Georgia State College - Documents/Projects/922 - Extreme Swainsboro Switch Refresh/newconfig'

foreach ($oldconfig in $AggregateData) {
    $NewConfig = @()
    $NewConfig += 'configure vlan Default ipaddress ' + $oldconfig.IpAddress
    $NewConfig += 'configure iproute add default ' + $oldconfig.DefaultGateway + ' vr VR-Default'

    # snmp
    $NewConfig += 'configure snmp sysName "' + $oldconfig.Hostname + '"'
    $NewConfig += 'configure snmp sysLocation "' + $oldconfig.Location + '"'
    $NewConfig += 'configure snmp sysContact "Ty Fagler"'
    $NewConfig += 'configure snmpv3 engine-id 03:20:9e:f7:c9:d3:2a'
    $NewConfig += 'configure snmpv3 add user "egcmgr" engine-id 80:00:07:7c:03:20:9e:f7:c9:d3:2a authentication md5 auth-encrypted localized-key 23:24:44:76:46:79:6b:39:48:59:73:45:54:75:6d:4c:63:62:2f:70:77:49:39:4c:78:76:33:32:51:33:69:52:61:78:66:4c:78:58:48:39:6d:52:67:37:31:4f:79:6e:61:53:4c:32:6f:3d privacy privacy-encrypted localized-key 23:24:64:78:4d:30:50:53:32:62:44:43:50:52:35:6c:79:32:6d:63:38:77:44:57:51:64:44:65:37:50:6b:38:58:54:4c:7a:42:39:73:4b:57:6e:71:54:56:73:69:47:49:32:4e:56:51:3d'
    $NewConfig += 'configure snmpv3 add group "v3rw" user "egcmgr" sec-model usm'
    $NewConfig += 'configure snmpv3 add access "v3rw" sec-model usm sec-level priv read-view "defaultAdminView" write-view "defaultAdminView" notify-view "defaultAdminView"'
    $NewConfig += 'enable snmp access'
    $NewConfig += 'disable snmp access snmp-v1v2c'
    $NewConfig += 'enable snmp access snmpv3'
    $NewConfig += 'disable snmpv3 default-group'

    # radius
    $NewConfig += 'configure radius mgmt-access primary server 168.22.248.150 1812 client-ip ' + ($oldconfig.IpAddress -replace '\/\d+','') + ' vr VR-Default'
    $NewConfig += 'configure radius mgmt-access primary shared-secret encrypted "#$9HVVmZ+xCp56xIJpt7rJiYuk2I64i6HJDgLM73qhHtlVRX9jgIU="'
    $NewConfig += 'configure radius netlogin primary server 168.22.248.150 1812 client-ip ' + ($oldconfig.IpAddress -replace '\/\d+','') + ' vr VR-Default'
    $NewConfig += 'configure radius netlogin primary shared-secret encrypted "#$PYSuqw/q38Keh5P3AzmkPSLWXXPi5ZETWO+FvRe9u+sd4c8jkT0="'
    $NewConfig += 'configure radius-accounting mgmt-access primary server 168.22.248.150 1813 client-ip ' + ($oldconfig.IpAddress -replace '\/\d+','') + ' vr VR-Default'
    $NewConfig += 'configure radius-accounting mgmt-access primary shared-secret encrypted "#$h0R+vmIJQ3jseXeCrJv9oPXwmEUdM6bGWX+CDUnBEK2F2kXec5k="'
    $NewConfig += 'configure radius-accounting netlogin primary server 168.22.248.150 1813 client-ip ' + ($oldconfig.IpAddress -replace '\/\d+','') + ' vr VR-Default'
    $NewConfig += 'configure radius-accounting netlogin primary shared-secret encrypted "#$YCzjimO8yNVQqE9uz+SnDFkEkWjTB8np3b2o7CQ+FG6JbJqiJBU="'

    # local account
    $NewConfig += 'configure account admin encrypted "$5$vGHB3v$GE4RBYnx4FWzOqeHPLdFsAXjVSpjXjIkMTnE1Ln7l29"'

    # sntp
    $sntpi = 0
    foreach ($server in $oldconfig.SntpServer) {
        $sntpi++
        if ($sntpi -gt 1) {
            $NewConfig += 'configure sntp-client secondary ' + $server + ' vr VR-Default'
        } else {
            $NewConfig += 'configure sntp-client primary ' + $server + ' vr VR-Default'
        }
    }
    $NewConfig += 'configure timezone name Eastern -300 autodst'

    $NewConfig += 'enable igmp snooping'
    $NewConfig += 'configure lldp ports all advertise vendor-specific dot3 link-aggregation'
    $NewConfig += 'configure lldp ports all advertise port-description system-name system-description management-address'

    foreach ($lag in $oldconfig.Lags) {
        $NewConfig += 'enable sharing ' + $lag.MasterPort + ' grouping ' + ($lag.Grouping -join ',') + ' algorithm address-based L2 lacp'
    }

    # aaa
    $NewConfig += 'create vlan unauth tag 999'
    $NewConfig += 'configure netlogin vlan unauth'
    $NewConfig += ''
    $NewConfig += '# NETLOGIN #'
    $NewConfig += ''
    $NewConfig += 'enable netlogin dot1x mac'
    $NewConfig += 'enable identity-management'
    $NewConfig += 'configure netlogin add mac-list ff:ff:ff:ff:ff:ff 48'
    $NewConfig += 'configure netlogin authentication protocol-order mac dot1x web-based'
    foreach ($port in $oldconfig.MacAuthentication) {
        $NewConfig += 'enable netlogin ports ' + $port + ' mac'
        $NewConfig += 'config identity-management add port ' + $port
    }
    $NewConfig += 'enable radius netlogin'
    $NewConfig += ''

    # stp
    $NewConfig += 'disable stpd'
    $NewConfig += 'configure stpd s0 mode dot1w'

    # vlan
    foreach ($vlan in $oldconfig.VlanConfig) {
        if ($vlan.Name -eq 'Default Vlan') {
            $vlan.Name = 'Default'
        } else {
            if ($null -eq $vlan.Name) {
                $vlan.Name = 'VLAN' + ($vlan.Id).ToString("0000")
            }
            $NewConfig += 'create vlan ' + $vlan.Name + ' tag ' + $vlan.Id
        }

        $NewConfig += 'enable stpd s0 auto-bind vlan ' + $vlan.Name

        foreach ($port in $vlan.UntaggedPorts) {
            $NewConfig += 'configure vlan ' + $vlan.Name + ' add ports ' + $port + ' untagged'
        }

        foreach ($port in $vlan.TaggedPorts) {
            $NewConfig += 'configure vlan ' + $vlan.Name + ' add ports ' + $port + ' tagged'
        }
        $NewConfig += 'enable igmp snooping vlan ' + $vlan.Name
    }

    # enable stp and safeguard
    $NewConfig += 'enable stpd'
    foreach ($port in $oldconfig.StpEdgePorts) {
        $NewConfig += 'configure stpd s0 ports edge-safeguard enable ' + $port + ' bpdu-restrict'
    }

    foreach ($port in $oldconfig.ForcedAuthPorts) {
        $NewConfig += 'disable netlogin ports ' + $port + ' mac'
        $NewConfig += 'disable netlogin ports ' + $port + ' dot1x'
    }

    # port aliases
    foreach ($port in $oldconifg.PortAlias) {
        $NewConfig += 'configure port ' + $port.Port + ' display-string "' + $port.Alias + '"'
    }

    $NewConfig += 'disable telnet'
    $NewConfig += 'disable web http'
    $NewConfig += 'enable ssh'

    $NewConfig += ''
    $NewConfig += '#'
    $NewConfig += '# policy'
    $NewConfig += '#'

    # manual policy mappings
    foreach ($port in $oldconfig.PortPolicy) {
        $OldPolicyId = $Port.Policy
        $NewConfig += 'configure policy port ' + $port.Port + ' admin-id ' + $PolicyMap.$OldPolicyId
    }

    $NewFileName = $oldconfig.Hostname + '-' + ($oldconfig.IpAddress -replace '\/\d+','') + '.txt'
    $OutputFile = Join-Path $OutputDirectory $NewFileName
    $NewConfig | Out-File -Path $OutputFile
}

 #>



<#
$OldConfigDir = '/Users/brian/Lockstep Technology Group/RHA - RHA Health Services - Documents/Projects/898 - Extreme Core Replacement/OldConfig'
$OutFile = Join-Path -Path $OldConfigDir -ChildPath 'out.xlsx'
$OldConfigFiles = gci $OldConfigDir

$ReturnObject = @()

foreach ($file in $OldConfigFiles) {
    $ConfigArray = gc $file
    $ThisHostname = (Get-CiscoHostConfig -ConfigArray $ConfigArray -ErrorAction SilentlyContinue).Name
    $ThisPortConfig = Get-CiscoPortConfig -ConfigArray $ConfigArray

    foreach ($port in $ThisPortConfig) {
        $new = "" | Select-Object 'Switch','PortName','Alias','PortChannel','Mode','NativeVlan','UntaggedVlan','TaggedVlan'

        $new.Switch = $ThisHostname
        $new.PortName = $port.Name
        $new.Alias = $port.Alias
        $new.PortChannel = $port.Aggregate
        $new.Mode = $port.Mode
        $new.NativeVlan = $port.NativeVlan
        $new.UntaggedVlan = $port.UntaggedVlan

        if ($port.Mode -eq 'trunk' -and $Port.TaggedVlan.Count -eq 0) {
            $new.TaggedVlan = '1-4094'
        }

        if ($port.TaggedVlan.Count -gt 1) {
            $new.TaggedVlan = ($port.TaggedVlan -join '|')
        }

        $ReturnObject += $new
    }
}

$ReturnObject | Export-Excel -Path $OutFile -Calculate -ClearSheet #>


<# # hp testing
$test = @()

$vlan = get-brocadevlanconfig -configpath $configPath
foreach ($v in $vlan) {
    foreach ($tport in $v.TaggedPorts) {

        if ($tport -match '18/') {
            $new = "" | Select vid, Port, tagged
            $new.vid = $v.Id
            $new.Port = $tport
            $new.tagged = 'tagged'
            $test += $new
        }
    }

    foreach ($tport in $v.UntaggedPorts) {
        if ($tport -match '18/') {
            $new = "" | Select vid, Port, tagged
            $new.vid = $v.Id
            $new.Port = $tport
            $new.tagged = 'untagged'
            $test += $new
        }
    }
}
 #>


#Get-HpArubaInventory -ConfigArray $StackConfig

<# $Vlans = Get-EosVlanConfig $ConfigPath
$Ports = Get-EosPortName $ConfigPath
$PortAlias = Get-EosPortAlias $ConfigPath

foreach ($p in $Ports) {
    $AliasLookup = $PortAlias | ? { $_.Name -eq $p.Name }
    if ($AliasLookup) {
        $p.Alias = $AliasLookup.Alias
    }
    foreach ($v in $Vlans) {
        if ($v.UntaggedPorts -contains $p.Name) {
            $p.UntaggedVlan = $v.Id
        }
        if ($v.TaggedPorts -contains $p.Name) {
            $p.TaggedVlan = $v.Id
        }
    }
}

$Ports | Select-Object Name, Alias, UntaggedVlan, @{n = 'TaggedVlan'; e = { $_.TaggedVlan -join ',' } } #>


#region msminv
#########################################################################
<#
$Files = gci $ConfigPath -Recurse
$ModuleFiles = $Files | ? { $_.Name -match '_modules' } | Sort-Object -Property FullName

$HpArubaStackRx = [regex] '\s+(?<member>\d+)\s+(?<slot>[A-Z\d](\/[A-Z\d]+)?|STK)\s+(?<model>.+?)(\s\s|\.\.\.\s)(?<serial>[^\ ]+?)\s+(?<status>[^\ ]+)'
$HpArubaStackMemberRx = [regex] '\s+(?<member>\d+)\s+(?<serial>[a-fA-F\-0-9]+)\s(?<model>.+)\s\s+\d+\ (?<status>Standby|Member|Commander)'
$HpArubaRx = [regex] '\s+(?<slot>[A-Z\d](\/[A-Z\d]+)?)\s+(?<model>.+?)(\s\s|\.\.\.\s)(?<serial>[^\ ]+?)\s+(?<status>[^\ ]+)'
$HpGbicRx = [regex] '\s+GBIC\s\d+\s\(\s+Port\s(?<slot>.+?)\):\s(?<model>.+?)\s+(?<serial>[^\ ]+)'
$HpArubaChassisRx = [regex] '\s+Chassis:\s([^\ ]+?)\s+(?<model>[^\ ]+?)\s+Serial\ Number:\s+(?<serial>.+)'
$CiscoRx = [regex] '^PID:\s(?<model>[^\ ]+)\s+,.+?SN:\ (?<serial>.+)'
$HpComwareRx = [regex] '^(?<model>.+?)\ uptime'

$Array = @()

foreach ($file in $ModuleFiles) {
    $Location = $file | Split-Path | Split-Path | Split-Path -Leaf
    Write-Verbose "$Location $($File.Name)"
    if ($file.Name -match '0.0.0.0') {
        continue
    }
    $content = gc $file
    if ($null -eq $content) {
        $verpath = Join-Path -Path ($file.FullName | Split-Path) -ChildPath (($file.FullName | split-path -Leaf) -replace 'modules', 'version')
        $content = gc $verpath
        $IsComware = $true
    }
    $ThisArray = @()
    foreach ($line in $content) {


        $HpArubaStackMatch = $HpArubaStackRx.Match($line)
        $HpArubaMatch = $HpArubaRx.Match($line)
        $HpArubaStackMemberMatch = $HpArubaStackMemberRx.Match($line)
        $HpGbicMatch = $HpGbicRx.Match($line)
        $CiscoMatch = $CiscoRx.Match($line)
        $HpArubaChassisMatch = $HpArubaChassisRx.Match($line)
        $HpComwareMatch = $HpComwareRx.Match($line)

        if ($HpArubaStackMatch.Success) {
            Write-Verbose "$Location $($File.Name) HpArubaStackMatch match: $($HpArubaStackMatch.Value)"
            $New = "" | Select Location, Filename, Member, Slot, Model, Serial, status

            $New.Location = $Location
            $New.Filename = $file.Name
            $New.Member = $HpArubaStackMatch.Groups['member'].Value.Trim()
            $New.Slot = $HpArubaStackMatch.Groups['slot'].Value.Trim()
            $New.Model = $HpArubaStackMatch.Groups['model'].Value.Trim()
            $New.Serial = $HpArubaStackMatch.Groups['serial'].Value.Trim()
            $New.Status = $HpArubaStackMatch.Groups['status'].Value.Trim()

            $ThisArray += $New
        } elseif ($HpArubaStackMemberMatch.Success) {
            Write-Verbose "$Location $($File.Name) HpArubaStackMemberMatch match: $($HpArubaStackMemberMatch.Value)"
            $New = "" | Select Location, Filename, Member, Slot, Model, Serial, status

            $New.Location = $Location
            $New.Filename = $file.Name
            $New.Member = $HpArubaStackMemberMatch.Groups['member'].Value.Trim()
            $New.Model = $HpArubaStackMemberMatch.Groups['model'].Value.Trim()
            $New.Serial = $HpArubaStackMemberMatch.Groups['serial'].Value.Trim()
            $New.Status = $HpArubaStackMemberMatch.Groups['status'].Value.Trim()

            $ThisArray += $New
        } elseif ($HpGbicMatch.Success) {
            Write-Verbose "$Location $($File.Name) HpGbicMatch match: $($HpGbicMatch.Value)"
            $New = "" | Select Location, Filename, Member, Slot, Model, Serial, status

            $New.Location = $Location
            $New.Filename = $file.Name
            $New.Slot = $HpGbicMatch.Groups['slot'].Value.Trim()
            $New.Model = $HpGbicMatch.Groups['model'].Value.Trim()
            $New.Serial = $HpGbicMatch.Groups['serial'].Value.Trim()

            $ThisArray += $New
        } elseif ($HpArubaChassisMatch.Success) {
            Write-Verbose "$Location $($File.Name)HpArubaChassisMatch match: $($HpArubaChassisMatch.Value)"
            $New = "" | Select Location, Filename, Member, Slot, Model, Serial, status

            $New.Location = $Location
            $New.Filename = $file.Name
            $New.Model = $HpArubaChassisMatch.Groups['model'].Value.Trim()
            $New.Serial = $HpArubaChassisMatch.Groups['serial'].Value.Trim()

            $ThisArray += $New
        } elseif ($HpArubaMatch.Success) {
            Write-Verbose "$Location $($File.Name) HpArubaMatch match: $($HpArubaMatch.Value)"
            $New = "" | Select Location, Filename, Member, Slot, Model, Serial, status

            $New.Location = $Location
            $New.Filename = $file.Name
            $New.Slot = $HpArubaMatch.Groups['slot'].Value.Trim()
            $New.Model = $HpArubaMatch.Groups['model'].Value.Trim()
            $New.Serial = $HpArubaMatch.Groups['serial'].Value.Trim()
            $New.Status = $HpArubaMatch.Groups['status'].Value.Trim()

            $ThisArray += $New
        } elseif ($CiscoMatch.Success) {
            Write-Verbose "$Location $($File.Name) CiscoMatch match: $($CiscoMatch.Value)"
            $New = "" | Select Location, Filename, Member, Slot, Model, Serial, status

            $New.Location = $Location
            $New.Filename = $file.Name
            $New.Model = $CiscoMatch.Groups['model'].Value.Trim()
            $New.Serial = $CiscoMatch.Groups['serial'].Value.Trim()

            $ThisArray += $New
        } elseif ($IsComware -and $HpComwareMatch.Success) {
            Write-Verbose "$Location $($File.Name) HpComwarematch match: $($HpComwareMatch.Value)"
            $New = "" | Select Location, Filename, Member, Slot, Model, Serial, status

            $New.Location = $Location
            $New.Filename = $file.Name
            $New.Model = $HpComwareMatch.Groups['model'].Value.Trim()

            $ThisArray += $New
        }
    }
    if ($ThisArray.Count -eq 0) {
        $New = "" | Select Location, Filename, Member, Slot, Model, Serial, status

        $New.Location = $Location
        $New.Filename = $file.Name
        $Array += $New
    } else {
        $Array += $ThisArray #| Select -Unique
    }

} #>

#########################################################################
#endregion msminv


<# $InputDirectory = '/Users/brian/OneDrive - Lockstep Technology Group/My Customers/Morehouse School of Medicine/Network Assessment/SwitchConfigs/'
$OutputFile = '/Users/brian/OneDrive - Lockstep Technology Group/My Customers/Morehouse School of Medicine/Network Assessment/RouteTables.xlsx'

$ResultArray = @()

foreach ($folder in (Get-ChildItem -Path $InputDirectory -Directory)) {
    Write-Verbose "Checking $($folder.Name)"
    $Files = Get-ChildItem -Path $folder.FullName -Exclude '*running-config*'
    $RunningConfigFile = Get-ChildItem -Path "$($folder.FullName)/*running-config*"

    $ConfigArray = (Get-Content -Path $RunningConfigFile)

    foreach ($file in $Files) {
        $ConfigArray += Get-Content -Path $file.FullName
    }

    if ($ConfigArray.Count -eq 0) {
        Write-Warning "No content for $($folder.Name)"
        continue
    }

    $SwitchType = Get-PsSwitchType -ConfigArray $ConfigArray -Verbose:$false
    Write-Verbose "SwitchType is $SwitchType"

}


$port = Get-EosPortName -ConfigArray $config -verbose
$vlan = Get-EosVlanConfig -ConfigArray $config

foreach ($v in $vlan) {
    foreach ($p in $v.UntaggedPorts) {
        $PortLookup = $port | ? { $_.Name -eq $p }
        $PortLookup.UntaggedVlan = $v.Id
        $PortLookup.NativeVlan = $v.Id
    }

    foreach ($p in $v.TaggedPorts) {
        $PortLookup = $port | ? { $_.Name -eq $p }
        $PortLookup.TaggedVlan += $v.Id
    }
}

#clear vlan 1
foreach ($p in $port) {
    $Vlan1 = $vlan | ? { $_.Id -eq 1 }
    if ($Vlan1.UntaggedPorts -notcontains $p.Name) {
        if ($p.NativeVlan -eq 1) {
            $p.NativeVlan = $null
        }
    }
} #>



#########################################################################
# Brocade conversion
#########################################################################

#$conffile = "/Users/brian/OneDrive - Lockstep Technology Group/My Customers/Fulton County Schools/Configs (1)/Esther Jackson Config/Backup_10.54.0.1_2019-11-02_04-04.txt"
#$conffile = "/Users/brian/OneDrive - Lockstep Technology Group/My Customers/Fulton County Schools/Heards Ferry/Backup_10.144.8.2_2018-05-16_12-53.txt"
#$conffile = "/Users/brian/OneDrive - Lockstep Technology Group/My Customers/Fulton County Schools/Heards Ferry/Backup_10.144.16.2_2019-08-30_04-04.txt"
#$conffile = "/Users/brian/OneDrive - Lockstep Technology Group/My Customers/Fulton County Schools/Heards Ferry/Backup_10.144.24.2_2018-05-16_12-54.txt"
#$conffile = "/Users/brian/OneDrive - Lockstep Technology Group/My Customers/Fulton County Schools/Heards Ferry/Backup_10.144.32.2_2018-06-27_15-18.txt"
#$conffile = "/Users/brian/OneDrive - Lockstep Technology Group/My Customers/Fulton County Schools/Heards Ferry/Backup_10.144.40.2_2018-06-27_17-15.txt"
#$conffile = "/Users/brian/OneDrive - Lockstep Technology Group/My Customers/Fulton County Schools/Heards Ferry/Backup_10.144.48.2_2018-06-27_15-25.txt"

<#
foreach ($folder in (gci $ConfigPath)) {
    Write-Verbose $folder.name
    $ConfigFilePath = Join-Path -Path $folder -ChildPath 'Configs'
    $ExcelFilePath = Join-Path -Path $folder -ChildPath "$($folder.Name).xlsx"

    # Get Inventory
    if ((gci $ConfigFilePath).Count -eq 0) {
        continue
    }
    $AllInventory = @()
    $ExcelInventory = @()

    foreach ($file in (gci $ConfigFilePath)) {
        Write-Warning $file.Name
        $Inventory = Get-BrocadeInventory -ConfigPath $file -Verbose:$false
        $AllInventory += $Inventory
        $ThisHostName = $Inventory.Hostname
        $ThisInventory = @()
        Write-Warning $ThisHostName

        #region InventoryFromConfig
        #####################################################

        if ($Inventory.ChassisMember.Count -gt 0) {
            $Type = 'ChassisMember'
        } elseif ($Inventory.StackMember.Count -gt 0) {
            $Type = 'StackMember'
        }

        foreach ($member in $Inventory.$Type) {
            $Entry = "" | Select-Object Hostname, Number, Module, Model
            $Entry.Hostname = $ThisHostName
            $Entry.Number = $member.Number
            $Entry.Module = $member.Module
            $Entry.Model = $member.Model

            $ThisInventory += $Entry
        }

        $ExcelInventory += $ThisInventory
    }

    $WorksheetName = 'InventoryFromConfig'
    $Excel = $ExcelInventory | Select-Object Hostname, Number, Module, Model `
    | Export-Excel -Path $ExcelFilePath -WorksheetName $WorksheetName -Verbose:$false -Calculate -FreezeTopRow -AutoSize -PassThru

    $WorksheetName = 'PortCountConfig'
    $Excel = $AllInventory | Select-Object Hostname, CopperPortTotal, FiberPortTotal, OneGigCopperPortCount, OneGigFiberCount,
    TenGigFiberCount, FortyGigFiberCount `
    | Export-Excel -Path $ExcelFilePath -WorksheetName $WorksheetName -Verbose:$false -Calculate -FreezeTopRow -AutoSize -PassThru

    Close-ExcelPackage $Excel

    $ImportExcel = Import-Excel -Path $ExcelFilePath -WorksheetName 'Walkthrough'

    $Comparison = @()

    $TopRow = "" | Select-Object Hostname, IDF, SwitchCount, CopperPortTotal, CopperPortTotalConfig, CopperPortInUse, FiberPortTotal, FiberPortTotalConfig, SingleModeFiberInUse, MultiModeFiberInUse, TenGigFiber, TenGigFiberConfig, TenGigFiberInUse, FortyGigFiberCount, PowerTotal, PowerAvailable, PowerInUse, SwitchingPowerInUse, CableManagement, ClosetCondition
    $TopRow.Hostname = 'Hostname'
    $TopRow.IDF = 'IDF'
    $TopRow.SwitchCount = 'SwitchCount'
    $TopRow.CopperPortTotal = 'CopperPorts'
    $TopRow.FiberPortTotal = 'FiberPorts'
    $TopRow.PowerTotal = 'PowerTotal '
    $TopRow.PowerAvailable = 'PowerAvailable'
    $TopRow.PowerInUse = 'PowerInUse '
    $TopRow.SwitchingPowerInUse = 'SwitchingPowerInUse'
    $TopRow.CableManagement = 'CableManagement'
    $TopRow.ClosetCondition = 'ClosetCondition'
    $Comparison += $TopRow

    $SecondRow = "" | Select-Object Hostname, IDF, SwitchCount, CopperPortTotal, CopperPortTotalConfig, CopperPortInUse, FiberPortTotal, FiberPortTotalConfig, SingleModeFiberInUse, MultiModeFiberInUse, TenGigFiber, TenGigFiberConfig, TenGigFiberInUse, FortyGigFiberCount, PowerTotal, PowerAvailable, PowerInUse, SwitchingPowerInUse, CableManagement, ClosetCondition
    $SecondRow.CopperPortTotal = 'TotalWalkthrough'
    $SecondRow.CopperPortTotalConfig = 'TotalConfig'
    $SecondRow.CopperPortInUse = 'TotalInUseWalkThrough'
    $SecondRow.FiberPortTotal = 'TotalWalkthrough'
    $SecondRow.FiberPortTotalConfig = 'TotalConfig'
    $SecondRow.SingleModeFiberInUse = 'SMInUseWalkThrough'
    $SecondRow.MultiModeFiberInUse = 'MMInUseWalkthrough'
    $SecondRow.TenGigFiber = '10GigFiberWalkthrough'
    $SecondRow.TenGigFiberConfig = '10GigFiberConfig'
    $SecondRow.TenGigFiberInUse = '10GigFiberInUseWalkthrough'
    $SecondRow.FortyGigFiberCount = '40GigFiberConfig'
    $Comparison += $SecondRow

    foreach ($closet in $ImportExcel) {
        if (-not $closet.Hostname) {
            Write-Warning 'Hostname not defined, add hostname from PortCountConfig and rerun'
            continue
        }

        $PortCountConfigLookup = $AllInventory | Where-Object { $_.Hostname -eq $closet.Hostname }

        $New = $closet | Select-Object Hostname, IDF, SwitchCount,
        CopperPortTotal,
        @{Name = "CopperPortTotalConfig"; Expression = { $PortCountConfigLookup.CopperPortTotal } },
        CopperPortInUse,
        @{Name = "FiberPortTotal"; Expression = { $_.TotalFiberPorts } },
        @{Name = "FiberPortTotalConfig"; Expression = { $PortCountConfigLookup.FiberPortTotal } },
        SingleModeFiberInUse, MultiModeFiberInUse,
        @{Name = "TenGigFiber"; Expression = { $_.'10Gig SFP+' } },
        @{Name = "TenGigFiberConfig"; Expression = { $PortCountConfigLookup.TenGigFiberCount } } ,
        @{Name = "TenGigFiberInUse"; Expression = { $_.'10Gig SFP+ InUse' } },
        @{Name = "FortyGigFiberCount"; Expression = { $PortCountConfigLookup.FortyGigFiberCount } } ,
        PowerTotal, PowerAvailable, PowerInUse, SwitchingPowerInUse, CableManagement, ClosetCondition

        $Comparison += $New
    }

    $WorksheetName = 'PortComparison'
    $Excel = $Comparison | Select-Object * `
    | Export-Excel -Path $ExcelFilePath -WorksheetName $WorksheetName -Verbose:$false -Calculate -AutoSize -PassThru -NoHeader -Activate

    if ($Comparison.Count -gt 2) {
        # Merge cells
        $WorkSheet = $Excel.Workbook.Worksheets['PortComparison']
        $WorkSheet.Cells['A1:A2'].Merge = $True
        $WorkSheet.Cells['B1:B2'].Merge = $True
        $WorkSheet.Cells['C1:C2'].Merge = $True
        $WorkSheet.Cells['D1:F1'].Merge = $True
        $WorkSheet.Cells['G1:N1'].Merge = $True
        $WorkSheet.Cells['O1:O2'].Merge = $True
        $WorkSheet.Cells['P1:P2'].Merge = $True
        $WorkSheet.Cells['Q1:Q2'].Merge = $True
        $WorkSheet.Cells['R1:R2'].Merge = $True
        $WorkSheet.Cells['S1:S2'].Merge = $True
        $WorkSheet.Cells['T1:T2'].Merge = $True

        # Center cells
        Set-ExcelRange -Range $WorkSheet.Cells['D1:F1'] -HorizontalAlignment Center
        Set-ExcelRange -Range $WorkSheet.Cells['G1:N1'] -HorizontalAlignment Center


        # Conditional Formatting
        $LastRow = $Comparison.Count
        Add-ConditionalFormatting -WorkSheet $WorkSheet -Range "`$D3:`$D$LastRow" -ForeGroundColor 'Red' -RuleType Expression -ConditionValue '=$D3<>$E3'
        Add-ConditionalFormatting -WorkSheet $WorkSheet -Range "`$G3:`$G$LastRow" -ForeGroundColor 'Red' -RuleType Expression -ConditionValue '=$G3<>$H3'
    }

    Close-ExcelPackage $Excel #>
    #####################################################
    #endregion InventoryFromConfig

<#     #region interfaces
    #####################################################
    Write-Verbose "$VerbosePrefix Getting Interfaces"
    $WorksheetName = 'InventoryFromConfig'

    $Excel = $Inventory | Select-Object Hostname, Comment, Vdom, Category, IpAddress, VlanId, IsDhcpClient, InterfaceType, ParentInterface,
    @{Name = "AggregateMember"; Expression = { $_.AggregateMember -join [Environment]::NewLine } },
    @{Name = "AllowedMgmtMethods"; Expression = { $_.AllowedMgmtMethods -join [Environment]::NewLine } },
    IsManagement, IsPPPoE `
    | Export-Excel -Path $ExcelPath -WorksheetName $WorksheetName -Verbose:$false -Calculate -FreezeTopRow -AutoSize -PassThru

    # add word wrap
    $WrapColumns = @()
    $WrapColumns += 'J'
    $WrapColumns += 'K'
    foreach ($col in $WrapColumns) {
        $Range = $Excel.Workbook.Worksheets[$WorksheetName].Dimension.Address -replace 'A1', "$col`2" -replace ':[A-Z]+', ":$col"
        Set-Format -WorkSheet $Excel.Workbook.Worksheets[$WorksheetName] -Range $Range -WrapText
    }

    Close-ExcelPackage $Excel
    #####################################################
    #endregion interfaces #>

#}
<#
$MdfMap = @{
    '2'  = '1'
    '6'  = '2'
    '15' = '3'
    '16' = '4'
}

$PortName = Get-BrocadePortName -ConfigArray $conf
$Vlan = Get-BrocadeVlanConfig -ConfigArray $conf
$Ip = Get-BrocadeIpInterface -ConfigArray $conf

$VlanOutput = @()

foreach ($v in $Vlan) {
    if (@(30, 40, 50) -contains $v.Id) {
        $VlanOutput += "vlan " + $v.Id

        # untagged
        $UntaggedString = ""
        foreach ($port in $v.UntaggedPorts) {
            if ($conffile -match 'Backup_10.144.0.1_2019') {
                if ($port -match '\b2\/') {
                    $port = $port -replace '2/', '1/'
                } elseif ($port -match '\b6\/') {
                    $port = $port -replace '6/', '2/'
                } elseif ($port -match '\b15\/') {
                    $port = $port -replace '15/', '3/'
                } elseif ($port -match '\b16\/') {
                    $port = $port -replace '16/', '4/'
                } else {
                    continue
                }
            }
            $port = $port -replace 'ethernet ', ''
            if ($port -notmatch '\d+\/[2-3]\/\d+') {
                $NewPortName = $port -replace '/1/', '/'
                if ($UntaggedString -ne "") {
                    $UntaggedString += ','
                }
                $UntaggedString += $NewPortName


            }
        }
        if ($UntaggedString -ne "") {
            if ($v.Id -eq 50) {
                $PoeString = $UntaggedString
            }
            $VlanOutput += "   untagged " + $UntaggedString
        }

        # tagged
        $TaggedString = ""
        foreach ($port in $v.taggedPorts) {
            if ($conffile -match 'Backup_10.144.0.1_2019') {
                if ($port -match '\b2\/') {
                    $port = $port -replace '2/', '1/'
                } elseif ($port -match '\b6\/') {
                    $port = $port -replace '6/', '2/'
                } elseif ($port -match '\b15\/') {
                    $port = $port -replace '15/', '3/'
                } elseif ($port -match '\b16\/') {
                    $port = $port -replace '16/', '4/'
                } else {
                    continue
                }
            }
            $port = $port -replace 'ethernet ', ''
            if ($port -notmatch '\d+\/[2-3]\/\d+') {

                $NewPortName = $port -replace '/1/', '/'
                if ($TaggedString -ne "") {
                    $TaggedString += ','
                }
                $TaggedString += $NewPortName
            }
        }
        if ($TaggedString -ne "") {
            $VlanOutput += "   tagged " + $TaggedString
        }
    }
}

if ($PoeString) {
    $VlanOutput += 'interface ' + $PoeString
    $VlanOutput += '   power-over-ethernet critical'
}

#$VlanOutput

$PortInventory = @()
$UniquePortTypes = ($PortName | Select -Unique Type).Type
foreach ($type in $UniquePortTypes) {
    $New = "" | Select IDF, SwitchCount, CopperPortTotal, SingleModeFiberInUse, MultiModeFiberInUse, TotalFiberPorts, PowerAvailable, CableManagement, ClosetCondition,
    $New.IDF =
    $New.PortType = $type
    $New.Count = ($PortName | ? { $_.Type -eq $type }).count

    $PortInventory += $New
}

$PortInventory
#>