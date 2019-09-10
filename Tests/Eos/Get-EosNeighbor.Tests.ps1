if (-not $ENV:BHProjectPath) {
    Set-BuildEnvironment -Path $PSScriptRoot\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force



InModuleScope $ENV:BHProjectName {
    $PSVersion = $PSVersionTable.PSVersion.Major
    $ProjectRoot = $ENV:BHProjectPath

    $Verbose = @{}
    if ($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose") {
        $Verbose.add("Verbose", $True)
    }

    $SampleSecureStackOutput = @'
Switch0(su)->show nei
    Port       Device ID            Port ID           Type       Network Address
---------------------------------------------------------------------------------
ge.1.1      00:1B:17:EB:77:88    ethernet1/1       lldp       10.8.72.2
ge.1.4      20b39970e40f         ge.1.1            ciscodp    10.8.72.3
ge.1.4      20:B3:99:70:E4:0F    ge.1.1            lldp
ge.1.12     10:65:30:C3:58:28    10-65-30-C3-58-28 lldp
ge.1.23     00:04:96:AE:75:71    23                lldp       10.8.128.50

Switch0(su)->show lldp port remote-info
Local Port   : ge.1.1      Remote Port Id : ethernet1/1
----------------------
Port Desc    : cor-ge.1.1
Mgmt Addr    : 10.8.72.2
Chassis ID   : 00:1B:17:EB:77:88
Sys Name     : pa1
Sys Desc     : Palo Alto Networks PA-3000 series firewall
Sys Cap Supported/Enabled      : other,repeater,bridge,router/other,router


Local Port   : ge.1.4      Remote Port Id : ge.1.1
----------------------
Chassis ID   : 20:B3:99:70:E4:0F


Local Port   : ge.1.12      Remote Port Id : 10-65-30-C3-58-28
----------------------
Chassis ID   : 10:65:30:C3:58:28
Device Type  : Generic Endpoint (class I)
Auto-Neg Supported/Enabled     : yes/yes
Auto-Neg Advertised            : Other
Operational Speed/Duplex/Type  :


Local Port   : ge.1.23      Remote Port Id : 23
----------------------
Port Desc    : cor_ge.1.23
Mgmt Addr    : 10.8.128.50
Chassis ID   : 00:04:96:AE:75:71
Sys Name     : switch2
Sys Desc     : ExtremeXOS (X450G2-24p-10G4) version 21.1.3.7 21.1.3.7 by release-manager on Mon Jan 30 10:47:48 EST 2017
Sys Cap Supported/Enabled      : bridge,router/bridge,router

ltg-wst-cor-001(su)->
'@
    $SampleSecureStackOutput = $SampleSecureStackOutput.Split([Environment]::NewLine)

    $SampleCoreSeriesOutput = @'
Switch0(su)->show neighbors -verbose
Port ge.1.1
    Neighbor                : 005f864df027
    System Name             : Switch1
    Description             : Cisco SG300-52MP (PID:SG300-52MP-K9)-VSD
    Vlan                    : 72
    MTU                     : 0
    Last Update             : THU JAN 01 00:00:00 1970
    CiscoDP
    Device Id             : 005f864df027
    Address               : 10.10.72.50
    Port                  : gi51
    Version               : 2
    Duplex                : Full Duplex
    Power                 : 0 milliwatts
    Support               : 0x02801

Port ge.1.2
    Neighbor                : 00-1f-45-fc-fc-53
    System Name             : Switch2
    Description             : K6 Chassis
    Location                : Kennesaw
    MTU                     : 0
    Last Update             : THU JAN 01 00:00:00 1970
    LLDP
    Chassis Id            : 00-1f-45-fc-fc-53
    Port                  : ge.1.1
    Support               :
    Enabled               :
    CiscoDP
    Device Id             : 00-1f-45-fc-fc-53
    Address               : 10.10.72.8
    Port                  : ge.1.1
    Version               : 2
    Primary Management    : 10.10.72.8
    Duplex                : Full Duplex
    Power                 : 0 milliwatts
    Support               : 0x02b01

Port ge.5.9
    Neighbor                : 20-b3-99-0e-20-ce
    System Name             : Switch3
    Description             : Enterasys C5
    Location                : Marietta
    Port                    : ge.1.24
    MTU                     : 0
    Last Update             : THU JAN 01 00:00:00 1970
    LLDP
    Chassis Id            : 20-b3-99-0e-20-ce
    Port                  : ge.1.24
    Support               :
    Enabled               :
    CDP
    Neighbor IP           : 10.10.72.207
    Chassis IP            : 10.10.72.207
    Chassis MAC           : 20-b3-99-0e-20-ce
    Device Type           : dot1qSwitch
    Support               : ieee8021q, gvrp, igmpSnoop
    CiscoDP
    Device Id             : 20b3990e20ce
    Address               : 10.10.72.207
    Port                  : ge.1.24
    Version               : 2
    Primary Management    : 10.10.72.207
    Duplex                : Full Duplex
    Power                 : 0 milliwatts
    Support               : 0x02b01

Switch0(su)->show lldp port remote-info

Local Port  : ge.1.5     Remote Port Id : ge.1.48
---------------------
Port Desc   : Unit: 1 1000BASE-T RJ45 Gigabit Ethernet Frontpanel Port 48 - no
                sfp inserted
Mgmt Addr   : 10.10.72.29
Chassis ID  : d8-84-66-29-25-d0
Sys Name    : Switch5
Sys Desc    : Enterasys Networks, Inc. B5G124-48P2 06.71.03.0025 Thu Oct  3
                11:47:47 2013
Sys Cap Supported/Enabled     : bridge,router/bridge,router

Auto-Neg Supported/Enabled    : yes/yes
Auto-Neg Advertised           : 10BASE-T, 10BASE-TFD
                                : 100BASE-TX, 100BASE-TXFD
                                : 1000BASE-TFD
                                : Bpause
Operational Speed/Duplex/Type : 1000/full/SX
Max Frame Size (bytes)        : 9216

Vlan Id                       : 72
LAG Supported/Enabled/Id      : yes/yes/418
Protocol Id : spanning tree v-3 (IEEE802.1s)
                LACP v-1

PoE Device                    : PSE device
PoE MDI Supported/Enabled     : yes/yes
PoE Pair Controllable/Used    : no/spare
PoE Power Class               : 0

Switch0(su)->

'@
    $SampleCoreSeriesOutput = $SampleCoreSeriesOutput.Split([Environment]::NewLine)

    Describe "Get-EosNeighbor" {
        Context "Core Series" {
            $Results = Get-EosNeighbor -ConfigArray $SampleSecureStackOutput

            It "Should find correct number of Neighbors" {
                $Results.Count | Should -BeExactly 3
            }
            Context "Neighbor details" {
                It "Should find first neighbor (10.8.72.2)" {
                    $Results[0].LocalPort | Should -BeExactly 'ge.1.1'
                    $Results[0].RemotePort | Should -BeExactly 'ethernet1/1'
                    $Results[0].DeviceId | Should -BeExactly '001b17eb7788'
                    $Results[0].DeviceName | Should -BeExactly 'pa1'
                    $Results[0].IpAddress | Should -BeExactly '10.8.72.2'
                    $Results[0].LinkLayerDiscoveryProtocol | Should -BeTrue
                    $Results[0].CabletronDiscoveryProtocol | Should -Not -BeTrue
                    $Results[0].CiscoDiscoveryProtocol | Should -Not -BeTrue
                    $Results[0].ExtremeDiscoveryProtocol | Should -Not -BeTrue
                }
                It "Should find first neighbor (10.8.72.3)" {
                    $Results[0].LocalPort | Should -BeExactly 'ge.1.4'
                    $Results[0].RemotePort | Should -BeExactly 'ethernet1/1'
                    $Results[0].DeviceId | Should -BeExactly '20b39970e40f'
                    $Results[0].DeviceName | Should -BeExactly 'pa1'
                    $Results[0].IpAddress | Should -BeExactly '10.8.72.3'
                    $Results[0].LinkLayerDiscoveryProtocol | Should -BeTrue
                    $Results[0].CabletronDiscoveryProtocol | Should -Not -BeTrue
                    $Results[0].CiscoDiscoveryProtocol | Should -Not -BeTrue
                    $Results[0].ExtremeDiscoveryProtocol | Should -Not -BeTrue
                }
                It "Should find first neighbor (10.8.72.2)" {
                    $Results[0].LocalPort | Should -BeExactly 'ge.1.12'
                    $Results[0].RemotePort | Should -BeExactly 'ge.1.1'
                    $Results[0].DeviceId | Should -BeExactly '10:65:30:C3:58:28'
                    $Results[0].DeviceName | Should -BeExactly 'pa1'
                    $Results[0].IpAddress | Should -BeExactly '10.8.72.2'
                    $Results[0].LinkLayerDiscoveryProtocol | Should -BeTrue
                    $Results[0].CabletronDiscoveryProtocol | Should -Not -BeTrue
                    $Results[0].CiscoDiscoveryProtocol | Should -Not -BeTrue
                    $Results[0].ExtremeDiscoveryProtocol | Should -Not -BeTrue
                }
                It "Should find first neighbor (10.8.72.2)" {
                    $Results[0].LocalPort | Should -BeExactly 'ge.1.23'
                    $Results[0].RemotePort | Should -BeExactly 'ethernet1/1'
                    $Results[0].DeviceId | Should -BeExactly '00:04:96:AE:75:71'
                    $Results[0].DeviceName | Should -BeExactly 'pa1'
                    $Results[0].IpAddress | Should -BeExactly '10.8.128.50'
                    $Results[0].LinkLayerDiscoveryProtocol | Should -BeTrue
                    $Results[0].CabletronDiscoveryProtocol | Should -Not -BeTrue
                    $Results[0].CiscoDiscoveryProtocol | Should -Not -BeTrue
                    $Results[0].ExtremeDiscoveryProtocol | Should -Not -BeTrue
                }
            }
            Describe "Get-PsNeighbor -PsSwitchType ExtremeEos" {
                $RouteTable = Get-PsNeighbor -ConfigArray $SampleSecureStackOutput -PsSwitchType ExtremeEos

                It "Should find correct number of Neighbors" {
                    $Results.Count | Should -BeExactly 3
                }
                Context "Neighbor details" {

                }
            }
        }
    }
}