if (-not $ENV:BHProjectPath) {
    Set-BuildEnvironment -Path $PSScriptRoot\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

InModuleScope $ENV:BHProjectName {
    $PSVersion = $PSVersionTable.PSVersion.Major
    $ProjectRoot = $ENV:BHProjectPath

    $Verbose = @{ }
    if ($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose") {
        $Verbose.add("Verbose", $True)
    }

    BeforeAll {
        #region dummydata
        ########################################################################
        $StackConfig = @'
Aruba-Stack-2930M# show system power-supply

Power Supply Status:

  Member  PS#   Model     Serial      State           AC/DC  + V        Wattage   Max
  ------- ----- --------- ----------- --------------- ----------------- --------- ------
  1       1     JL086A    CN9AGZ93B2  Powered         AC 120V/240V        27       680
  1       2     JL086A    CN90GZ98H4  Not Powered     AC 120V/240V        22       680
Aruba-Stack-2930M# show system

 Status and Counters - General System Information

  System Name        : Aruba-Stack-2930M
  System Contact     :
  System Location    :
  MAC Age Time (sec) : 300
  Time Zone          : 0
  Daylight Time Rule : None

  Software revision  : WC.16.07.0003
  Base MAC Addr      : 9020c2-fcddca

  Member :1

  ROM Version        : WC.17.02.0006
  Up Time            : 20 hours
  CPU Util (%)       : 9
  MAC Addr           : 9020c2-fb8080
  Serial Number      : SG98JQNY1Y
  Memory   - Total   : 342,344,192
             Free    : 183,033,720



 Member :2

  ROM Version        : WC.17.02.0006
  Up Time            : 39 mins
  CPU Util (%)       : 0
  MAC Addr           : 9020c2-fcddc0
  Serial Number      : SG98JQNYXR
  Memory   - Total   : 342,344,192
             Free    : 197,818,472

Aruba-Stack-2930M# show interfaces transceiver

Transceiver Technical Information:

                     Product      Serial             Part
 Port    Type        Number       Number             Number
 ------- ----------- ------------ ------------------ ----------
 1/A1    SFP+SR      J9150D       CN98KJWFGX         1990-4634
 1/A2    SFP+DA1     J9281D       CN96KBZCS2         8121-1300


Aruba-Stack-2930M# show modules

 Status and Counters - Module Information


  Stack ID       : NO ID - will merge upon connectivity

  Member
  ID     Slot     Module Description                  Serial Number    Status
  ------ -------- ----------------------------------- ---------------- -------
  1      A        Aruba JL083A 4p 10GbE SFP+ Module   SG90GZ62QQ       Up
  1      STK      Aruba JL325A 2p Stacking Module     SG9BJQR1Z7       Up

Aruba-Stack-2930M# show conf

Startup configuration: 2

; hpStack_WC Configuration Editor; Created on release #WC.16.07.0003
; Ver #14:01.4f.f8.1d.9b.3f.bf.bb.ef.7c.59.fc.6b.fb.9f.fc.ff.ff.37.ef:02

stacking
   member 1 type "JL322A" mac-address 9020c2-fb8080
   member 1 flexible-module A type JL083A
   member 2 type "JL322A" mac-address 9020c2-fcddc0
   member 2 flexible-module A type JL083A
   exit
hostname "Aruba-Stack-2930M"
snmp-server community "public" unrestricted
oobm
   ip address dhcp-bootp
   member 1
      ip address dhcp-bootp
      exit
   exit
vlan 1
   name "DEFAULT_VLAN"
   untagged 1/1-1/48,1/A1-1/A4
   ip address dhcp-bootp
   ipv6 enable
   ipv6 address dhcp full
   exit
'@
        $StackConfig = $StackConfig.Split([Environment]::NewLine)
        $ParsedObject = Get-HpArubaInventory -ConfigArray $StackConfig
        ########################################################################
        #endregion dummydata
    }

    Describe "Get-HpArubaInventory" {
        #region stack
        ########################################################################
        Context StackConfig {
            It "should return correct number of objects" {
                $ParsedObject.ChassisMember.Count | Should -BeExactly 0
                $ParsedObject.StackMember.Count | Should -BeExactly 4
                $ParsedObject.CopperPortTotal | Should -BeExactly 96
                $ParsedObject.FiberPortTotal | Should -BeExactly 12
                $ParsedObject.OneGigCopperPortCount | Should -BeExactly 96
                $ParsedObject.OneGigFiberCount | Should -BeExactly 8
                $ParsedObject.TenGigFiberCount | Should -BeExactly 4
                $ParsedObject.FortyGigFiberCount | Should -BeExactly 0
                $ParsedObject.PowerSupply.Count | Should -BeExactly 2
                $ParsedObject.Transceiver.Count | Should -BeExactly 2
                $ParsedObject.Hostname | Should -BeExactly 'Aruba-Stack-2930M'
            }
            Context 'Stack Member 1' {
                <#                 It "should return main switch correctly" {
                    $ThisObject = $ParsedObject.StackMember[0]
                    $ThisObject.Number | Should -BeExactly 1
                    $ThisObject.Model | Should -BeExactly 'JL322A'
                    $ThisObject.Description | Should -BeExactly 'Aruba 2930M 48G PoE+ 1-slot Switch'
                    $ThisObject.SerialNumber | Should -BeExactly 'SG98JQNYXR'
                    $ThisObject.MacAddress | Should -BeExactly '9020c2-fcddc0'
                } #>
                It "should return power supplies correctly" {
                    $ThisObject = $ParsedObject.PowerSupply
                    $ThisObject.Count | Should -BeExactly 2

                    # first power supply
                    $ThisObject[0].Model | Should -BeExactly 'JL086A'
                    $ThisObject[0].Description | Should -BeExactly 'Aruba X372 54VDC 680W Power Supply'
                    $ThisObject[0].StackMember | Should -BeExactly 1
                    $ThisObject[0].PsuNumber | Should -BeExactly 1
                    $ThisObject[0].SerialNumber | Should -BeExactly 'CN9AGZ93B2'
                    $ThisObject[0].IsPowered | Should -BeTrue
                    $ThisObject[0].PowerType | Should -BeExactly 'AC'
                    $ThisObject[0].AcVoltage | Should -BeExactly 120
                    $ThisObject[0].DcVoltage | Should -BeExactly 240
                    $ThisObject[0].CurrentWattage | Should -BeExactly 27
                    $ThisObject[0].MaxWattage | Should -BeExactly 680

                    # second power supply
                    $ThisObject[1].Model | Should -BeExactly 'JL086A'
                    $ThisObject[1].Description | Should -BeExactly 'Aruba X372 54VDC 680W Power Supply'
                    $ThisObject[1].StackMember | Should -BeExactly 1
                    $ThisObject[1].PsuNumber | Should -BeExactly 2
                    $ThisObject[1].SerialNumber | Should -BeExactly 'CN90GZ98H4'
                    $ThisObject[1].IsPowered | Should -BeFalse
                    $ThisObject[1].PowerType | Should -BeExactly 'AC'
                    $ThisObject[1].AcVoltage | Should -BeExactly 120
                    $ThisObject[1].DcVoltage | Should -BeExactly 240
                    $ThisObject[1].CurrentWattage | Should -BeExactly 22
                    $ThisObject[1].MaxWattage | Should -BeExactly 680
                }
                It "should return transceviers correctly" {
                    $ThisObject = $ParsedObject.Transceiver
                    $ThisObject.Count | Should -BeExactly 2

                    # first transceiver
                    $ThisObject[0].Model | Should -BeExactly 'J9150D'
                    $ThisObject[0].Description | Should -BeExactly 'Aruba 10G SFP+ LC SR 300m MMF XCVR'
                    $ThisObject[0].Type | Should -BeExactly 'SFP+'
                    $ThisObject[0].SubType | Should -BeExactly 'SR'
                    $ThisObject[0].CableType | Should -BeExactly 'Multimode Fiber'
                    $ThisObject[0].SpeedInMbps | Should -BeExactly 10000
                    $ThisObject[0].DistanceInMeters | Should -BeExactly 300

                    # second transceiver
                    $ThisObject[1].Model | Should -BeExactly 'J9281D'
                    $ThisObject[1].Description | Should -BeExactly 'Aruba 10G SFP+ to SFP+ 1m DAC Cable'
                    $ThisObject[1].Type | Should -BeExactly 'SFP+'
                    $ThisObject[1].SubType | Should -BeExactly 'DA1'
                    $ThisObject[1].CableType | Should -BeExactly 'Direct Attach'
                    $ThisObject[1].SpeedInMbps | Should -BeExactly 10000
                    $ThisObject[1].DistanceInMeters | Should -BeExactly 1
                }
            }
        }
        ########################################################################
        #endregion stack
    }
}