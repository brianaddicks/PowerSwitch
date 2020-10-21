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

    BeforeAll {
        $SSAOutput = @'
ssa(su)->show system hardware all

CHASSIS HARDWARE INFORMATION
----------------------------

    Chassis Type:               SSA Chassis (0x15)
    Chassis Serial Number:      17380249686C
    Chassis Version:            0
    Chassis Power Redundancy:   Not Redundant
    Chassis Power Supply 1:     Installed & Operating
                                Type = SSA-FB-AC-PS-A
                                Power = 460 Watts
                                Input/output type = AC/DC
                                Input status = OK
                                Output status = OK
                                Fan 1 speed = 10463 RPM
    Chassis Power Supply 2:     Not Installed
    Chassis Fan 1:              Installed & Operating
    Chassis Fan 2:              Installed & Operating
    PoE Power Redundancy:       Redundancy Not Supported
    PoE Power Supply 1:         Not Supported
    PoE Power Supply 2:         Not Supported
    Ambient Temperature:        33.50  C

SYSTEM SLOT HARDWARE INFORMATION
--------------------------------

    SLOT 1
        Model:                   SSA-G8018-0652
        Part Number:             9404462
        Serial Number:           17380249686C
        Vendor ID:               1
        Base MAC Address:        D8-84-66-9B-76-05
        MAC Address Count:       54
        Uptime:                  0144,14:35:16 (d,h:m:s)
        Style:                   Unknown
        Hardware Version:        2
        Firmware Version:        08.41.01.0004
        BootCode Version:        01.03.03
        BootPROM Version:        01.02.02
        CPU Version:             28674 (PPC 750GX)
        SDRAM:                   2048 MB
        NVRAM:                   32  KB
        Flash System:            0    MB
            /flash0 free space:   34  MB
            /flash1 free space:   67  MB
            /flash2 free space:   837 MB
        Temperature:
            LM75 Sensor 1:        34.500  C
            LM75 Sensor 2:        33.500  C
            LM75 Sensor 3:        26.500  C
        Dip Switch Bank          1    2    3    4    5    6    7    8
            Position:             OFF  OFF  OFF  OFF  OFF  OFF  OFF  OFF
        HOST CHIP:
            Type:                 FPGA
            Revision:             898   (0x382)
        FABRIC ACCESS PROC CHIP:
            FAP CHIP [0]:         PETRA Revision B
        FABRIC ELEMENT CHIP:
            FEs:                  Not present
        PLD CHIP:
            CHIP [0] Revision:    8     (0x8)
        NIM[0]:                  Not Supported
        NIM[1]:                  Not Present
        NIM[2]:
            Description:          48 Port 1G SFP (1X) & 4 Port 10G SFP+ (2X)
            PLD Revision:         187   (0xBB)
            FRU:                  no
            PoE:                  Not supported
            SWITCH CHIP[0]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                0
            SWITCH CHIP[1]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                1
            SWITCH CHIP[2]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                2
            SWITCH CHIP[3]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                3
            SWITCH CHIP[4]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                4
            SWITCH CHIP[5]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                5
            MAC CHIP [0]:
            Model:             BCM56521
            Revision:          17
            Id:                8
            MAC CHIP [1]:
            Model:             BCM56521
            Revision:          17
            Id:                9
            MAC CHIP [2]:
            Model:             BCM56628
            Revision:          19
            Id:                10
            PHY CHIP [0]:
            Model:             BCM56521 Internal
            Revision:          0
            Id:                16
            PHY CHIP [1]:
            Model:             BCM56521 Internal
            Revision:          0
            Id:                17
            PHY CHIP [2]:
            Model:             BCM8729
            Revision:          12
            Microcode Version: 0x0516
            Id:                18
            PHY CHIP [3]:
            Model:             BCM8729
            Revision:          12
            Microcode Version: 0x0516
            Id:                19
        NIM[3]:                  Not Supported

ssa(su)->
'@

        $SecureStackOutput = @'
A4(su)->show system hardware

        UNIT 1 HARDWARE INFORMATION
        ---------------------------
        Model:                          A4H124-48P
        Serial Number:                  15060182915Y
        Vendor ID:                      0xbc00
        Base MAC Address:               D8:84:66:1B:69:3F
        Hardware Version:               BCM5655 REV 18
        FirmWare Version:               06.71.03.0025
        Boot Code Version:              01.00.51
        CPLD Version:                   2.1
        POE Version:                    608_3

        UNIT 2 HARDWARE INFORMATION
        ---------------------------
        Model:                          A4H124-48P
        Serial Number:                  12430191915R
        Vendor ID:                      0xbc00
        Base MAC Address:               20:B3:99:76:49:C7
        Hardware Version:               BCM5655 REV 18
        FirmWare Version:               06.71.03.0025
        Boot Code Version:              01.00.51
        CPLD Version:                   2.1
        POE Version:                    608_3

A4(su)->
'@

        $S4Output = @'
S4(su)->show system hardware all

CHASSIS HARDWARE INFORMATION
----------------------------

    Chassis Type:               S4 Chassis (0x12)
    Chassis Serial Number:      11485379635U
    Chassis Power Redundancy:   Redundant
    Chassis Power Available:    3600 Watts
    Chassis Power Allocated:    967 Watts
    Chassis Power Unused:       2633 Watts
    Chassis Power Supply 1:     Installed & Not Operating
                                Type = unknown
                                Power = unknown
                                Input/output type = AC/DC
                                Input status = OK (low AC input power)
                                Output status = Not OK
                                Fan 1 speed = 2400 RPM
                                Fan 2 speed = 2550 RPM
    Chassis Power Supply 2:     Installed & Operating
                                Type = S-AC-PS
                                Power = 1200 Watts
                                Input/output type = AC/DC
                                Input status = OK (low AC input power)
                                Output status = OK
                                Fan 1 speed = 9750 RPM
                                Fan 2 speed = 9990 RPM
    Chassis Power Supply 3:     Installed & Operating
                                Type = S-AC-PS
                                Power = 1200 Watts
                                Input/output type = AC/DC
                                Input status = OK (low AC input power)
                                Output status = OK
                                Fan 1 speed = 10350 RPM
                                Fan 2 speed = 10650 RPM
    Chassis Power Supply 4:     Installed & Operating
                                Type = S-AC-PS
                                Power = 1200 Watts
                                Input/output type = AC/DC
                                Input status = OK (low AC input power)
                                Output status = OK
                                Fan 1 speed = 3750 RPM
                                Fan 2 speed = 3600 RPM
    Chassis Fan:                Installed & Operating
    Fan Temperature:            23.000  C
    PoE Power Shelf:            Not Present
    PoE Power Redundancy:       Redundancy Not Supported
    PoE Power Supply 1:         Info Not Available
    PoE Power Supply 2:         Info Not Available
    PoE Power Supply 3:         Info Not Available
    PoE Power Supply 4:         Info Not Available
    PoE Power Supply 5:         Info Not Available
    PoE Power Supply 6:         Info Not Available
    PoE Power Supply 7:         Info Not Available
    PoE Power Supply 8:         Info Not Available
    Ambient Temperature:        20.0  C

SYSTEM SLOT HARDWARE INFORMATION
--------------------------------

    SLOT 2
        Model:                   ST1206-0848-F6
        Part Number:             9404360
        Serial Number:           12235285636M
        Vendor ID:               1
        Base MAC Address:        20-B3-99-55-8C-73
        MAC Address Count:       50
        Style:                   2
        Hardware Version:        6
        Firmware Version:        07.71.02.0005
        BootCode Version:        01.01.00
        BootPROM Version:        01.01.05
        CPU Version:             28674 (PPC 750GX)
        SDRAM:                   1024 MB
        NVRAM:                   32  KB
        Flash System:            1024 MB
            /flash0 free space:   43  MB
            /flash1 free space:   62  MB
            /flash2 free space:   804 MB
        Temperature:
            LM75:                 57.000  C
        Dip Switch Bank          1    2    3    4    5    6    7    8
            Position:             OFF  OFF  OFF  OFF  OFF  OFF  OFF  OFF
        HOST CHIP:
            Type:                 FPGA
            Revision:             898   (0x382)
        FABRIC ACCESS PROC CHIP:
            FAP CHIP [0]:         FAP21V Revision A
            FAP CHIP [1]:         FAP21V Revision A
            FAP CHIP [2]:         FAP21V Revision A
            FAP CHIP [3]:         FAP21V Revision A
        FABRIC ELEMENT CHIP:
            FE CHIP [0]:          FE200M
            FE CHIP [1]:          FE200M
            FE CHIP [2]:          FE200M
            FE CHIP [3]:          FE200M
        PLD CHIP:
            Revision:             8     (0x8)
        NIM[0] - Option Module NEM200:
            Model:                SOG1201-0112
            Part Number:          9404327
            Serial Number:        12070259595J
            Base MAC Address:     00-1F-45-FF-52-B7
            MAC Address Count:    12
            Style:                2
            Location:             upper right
            Description:          12 Port 1G SFP, 1X, Double-Wide Top
            Board Revision:       8     (0x8)
            PLD Revision:         5     (0x5)
            FRU:                  yes (NEM200)
            PoE:                  Not supported
            SWITCH CHIP[0]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                5
            MAC CHIP [0]:
            Model:             BCM56620
            Revision:          18
            Id:                0
            PHY CHIP [0]:
            Model:             BCM56620 Internal
            Revision:          0
            Id:                0
        NIM[1]:
            Location:             lower right
            Description:          24 Port 10/100/1000 RJ45, 1X, Double-Wide Bottom, PoE+ Capable
            Board Revision:       8     (0x8)
            PLD Revision:         15    (0xF)
            FRU:                  no
            PoE[1]:
            Software Revision: Unavailable
            Device Id:         Unavailable
            SWITCH CHIP[0]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                2
            SWITCH CHIP[1]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                3
            MAC CHIP [0]:
            Model:             BCM56620
            Revision:          18
            Id:                4
            PHY CHIP [0]:
            Model:             BCM54980
            Revision:          4
            Id:                6
            PHY CHIP [1]:
            Model:             BCM54980
            Revision:          4
            Id:                7
            PHY CHIP [2]:
            Model:             BCM54980
            Revision:          4
            Id:                8
        NIM[2]:
            Location:             lower left
            Description:          24 Port 10/100/1000 RJ45, 1X, Double-Wide Bottom, PoE+ Capable
            Board Revision:       8     (0x8)
            PLD Revision:         15    (0xF)
            FRU:                  no
            PoE[2]:
            Software Revision: Unavailable
            Device Id:         Unavailable
            SWITCH CHIP[0]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                0
            SWITCH CHIP[1]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                1
            MAC CHIP [0]:
            Model:             BCM56620
            Revision:          18
            Id:                8
            PHY CHIP [0]:
            Model:             BCM54980
            Revision:          4
            Id:                12
            PHY CHIP [1]:
            Model:             BCM54980
            Revision:          4
            Id:                13
            PHY CHIP [2]:
            Model:             BCM54980
            Revision:          4
            Id:                14
        NIM[3] - Option Module NEM100:
            Model:                SOK1208-0104
            Part Number:          9404324
            Serial Number:        12240548595L
            Base MAC Address:     20-B3-99-5E-82-A3
            MAC Address Count:    4
            Style:                2
            Location:             upper left
            Description:          4 Port 10G SFP+, 4X, Double-Wide Top
            Board Revision:       8     (0x8)
            PLD Revision:         6     (0x6)
            FRU:                  yes (NEM100)
            PoE:                  Not supported
            SWITCH CHIP[0]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                4
            MAC CHIP [0]:
            Model:             BCM56628
            Revision:          19
            Id:                12
            PHY CHIP [0]:
            Model:             BCM8727
            Revision:          6
            Microcode Version: 0x0406
            Id:                18
            PHY CHIP [1]:
            Model:             BCM8727
            Revision:          6
            Microcode Version: 0x0406
            Id:                19

    SLOT 3
        Model:                   ST1206-0848-F6
        Part Number:             9404360
        Serial Number:           12225145636M
        Vendor ID:               1
        Base MAC Address:        20-B3-99-55-37-1D
        MAC Address Count:       50
        Style:                   2
        Hardware Version:        6
        Firmware Version:        07.71.02.0005
        BootCode Version:        01.01.00
        BootPROM Version:        01.01.05
        CPU Version:             28674 (PPC 750GX)
        SDRAM:                   1024 MB
        NVRAM:                   32  KB
        Flash System:            1024 MB
            /flash0 free space:   43  MB
            /flash1 free space:   62  MB
            /flash2 free space:   803 MB
        Temperature:
            LM75:                 57.500  C
        Dip Switch Bank          1    2    3    4    5    6    7    8
            Position:             OFF  OFF  OFF  OFF  OFF  OFF  OFF  OFF
        HOST CHIP:
            Type:                 FPGA
            Revision:             898   (0x382)
        FABRIC ACCESS PROC CHIP:
            FAP CHIP [0]:         FAP21V Revision A
            FAP CHIP [1]:         FAP21V Revision A
            FAP CHIP [2]:         FAP21V Revision A
            FAP CHIP [3]:         FAP21V Revision A
        FABRIC ELEMENT CHIP:
            FE CHIP [0]:          FE200M
            FE CHIP [1]:          FE200M
            FE CHIP [2]:          FE200M
            FE CHIP [3]:          FE200M
        PLD CHIP:
            Revision:             8     (0x8)
        NIM[0] - Option Module NEM200:
            Model:                SOG1201-0112
            Part Number:          9404327
            Serial Number:        12070250595J
            Base MAC Address:     00-1F-45-FF-52-4B
            MAC Address Count:    12
            Style:                2
            Location:             upper right
            Description:          12 Port 1G SFP, 1X, Double-Wide Top
            Board Revision:       8     (0x8)
            PLD Revision:         5     (0x5)
            FRU:                  yes (NEM200)
            PoE:                  Not supported
            SWITCH CHIP[0]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                5
            MAC CHIP [0]:
            Model:             BCM56620
            Revision:          18
            Id:                0
            PHY CHIP [0]:
            Model:             BCM56620 Internal
            Revision:          0
            Id:                0
        NIM[1]:
            Location:             lower right
            Description:          24 Port 10/100/1000 RJ45, 1X, Double-Wide Bottom, PoE+ Capable
            Board Revision:       8     (0x8)
            PLD Revision:         15    (0xF)
            FRU:                  no
            PoE[1]:
            Software Revision: Unavailable
            Device Id:         Unavailable
            SWITCH CHIP[0]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                2
            SWITCH CHIP[1]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                3
            MAC CHIP [0]:
            Model:             BCM56620
            Revision:          18
            Id:                4
            PHY CHIP [0]:
            Model:             BCM54980
            Revision:          4
            Id:                6
            PHY CHIP [1]:
            Model:             BCM54980
            Revision:          4
            Id:                7
            PHY CHIP [2]:
            Model:             BCM54980
            Revision:          4
            Id:                8
        NIM[2]:
            Location:             lower left
            Description:          24 Port 10/100/1000 RJ45, 1X, Double-Wide Bottom, PoE+ Capable
            Board Revision:       8     (0x8)
            PLD Revision:         15    (0xF)
            FRU:                  no
            PoE[2]:
            Software Revision: Unavailable
            Device Id:         Unavailable
            SWITCH CHIP[0]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                0
            SWITCH CHIP[1]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                1
            MAC CHIP [0]:
            Model:             BCM56620
            Revision:          18
            Id:                8
            PHY CHIP [0]:
            Model:             BCM54980
            Revision:          4
            Id:                12
            PHY CHIP [1]:
            Model:             BCM54980
            Revision:          4
            Id:                13
            PHY CHIP [2]:
            Model:             BCM54980
            Revision:          4
            Id:                14
        NIM[3] - Option Module NEM100:
            Model:                SOK1208-0104
            Part Number:          9404324
            Serial Number:        12240554595L
            Base MAC Address:     20-B3-99-5E-7D-AE
            MAC Address Count:    4
            Style:                2
            Location:             upper left
            Description:          4 Port 10G SFP+, 4X, Double-Wide Top
            Board Revision:       8     (0x8)
            PLD Revision:         6     (0x6)
            FRU:                  yes (NEM100)
            PoE:                  Not supported
            SWITCH CHIP[0]:
            Type:              ASIC
            Revision:          3327 (0xCFF)
            Id:                4
            MAC CHIP [0]:
            Model:             BCM56628
            Revision:          19
            Id:                12
            PHY CHIP [0]:
            Model:             BCM8727
            Revision:          6
            Microcode Version: 0x0406
            Id:                18
            PHY CHIP [1]:
            Model:             BCM8727
            Revision:          6
            Microcode Version: 0x0406
            Id:                19

S4(su)->
'@

        $SecureStackSingleUnitOutput = @'
C3(su)->show system hardware
        SLOT HARDWARE INFORMATION
        ---------------------------
        Model:                          C3G124-48
        Serial Number:                  09380615225K
        Vendor ID:                      0xbc00
        Base MAC Address:               00:1F:45:4F:60:E8
        Hardware Version:               BCM56504 REV 19
        FirmWare Version:               06.42.10.0016
        Boot Code Version:              01.00.52
        CPLD Version:                   2.0

C3(su)->
'@

    }

    Describe "Get-EosInventory" {
        Context "SSA" {
            BeforeAll {
                $SampleOutput = $SSAOutput.Split([Environment]::NewLine)
                $ParsedOutput = Get-EosInventory -ConfigArray $SampleOutput
            }
            It "Should parse the chassis correctly" {
                $ThisSlot = $ParsedOutput[0]
                $ThisSlot.Slot | Should -BeExactly 'Chassis'
                $ThisSlot.Model | Should -BeExactly 'SSA Chassis (0x15)'
                $ThisSlot.Serial | Should -BeExactly '17380249686C'
            }
            It "Should parse psu1 correctly" {
                $ThisSlot = $ParsedOutput[1]
                $ThisSlot.Slot | Should -BeExactly 'PSU1'
                $ThisSlot.Model | Should -BeExactly 'SSA-FB-AC-PS-A'
                $ThisSlot.Status | Should -BeExactly 'Installed & Operating'
            }
            It "Should parse psu2 correctly" {
                $ThisSlot = $ParsedOutput[2]
                $ThisSlot.Slot | Should -BeExactly 'PSU2'
                $ThisSlot.Model | Should -BeExactly 'unknown-psu'
                $ThisSlot.Status | Should -BeExactly 'Not Installed'
            }
            It "Should parse slot 1 correctly" {
                $ThisSlot = $ParsedOutput[3]
                $ThisSlot.Slot | Should -BeExactly '1'
                $ThisSlot.Model | Should -BeExactly 'SSA-G8018-0652'
                $ThisSlot.Serial | Should -BeExactly '17380249686C'
                $ThisSlot.Firmware | Should -BeExactly '08.41.01.0004'
            }
        }
        Context "S4" {
            BeforeAll {
                $SampleOutput = $S4Output.Split([Environment]::NewLine)
                $ParsedOutput = Get-EosInventory -ConfigArray $SampleOutput
            }
            It "Should parse the chassis correctly" {
                $ThisSlot = $ParsedOutput[0]
                $ThisSlot.Slot | Should -BeExactly 'Chassis'
                $ThisSlot.Model | Should -BeExactly 'S4 Chassis (0x12)'
                $ThisSlot.Serial | Should -BeExactly '11485379635U'
            }
            It "Should parse slot psu1 correctly" {
                $ThisSlot = $ParsedOutput[1]
                $ThisSlot.Slot | Should -BeExactly 'PSU1'
                $ThisSlot.Model | Should -BeExactly 'unknown'
                $ThisSlot.Status | Should -BeExactly 'Installed & Not Operating'
            }
            It "Should parse slot psu2 correctly" {
                $ThisSlot = $ParsedOutput[2]
                $ThisSlot.Slot | Should -BeExactly 'PSU2'
                $ThisSlot.Model | Should -BeExactly 'S-AC-PS'
                $ThisSlot.Status | Should -BeExactly 'Installed & Operating'
            }
            It "Should parse slot psu3 correctly" {
                $ThisSlot = $ParsedOutput[3]
                $ThisSlot.Slot | Should -BeExactly 'PSU3'
                $ThisSlot.Model | Should -BeExactly 'S-AC-PS'
                $ThisSlot.Status | Should -BeExactly 'Installed & Operating'
            }
            It "Should parse slot psu4 correctly" {
                $ThisSlot = $ParsedOutput[4]
                $ThisSlot.Slot | Should -BeExactly 'PSU4'
                $ThisSlot.Model | Should -BeExactly 'S-AC-PS'
                $ThisSlot.Status | Should -BeExactly 'Installed & Operating'
            }
            It "Should parse slot 2 correctly" {
                $ThisSlot = $ParsedOutput[5]
                $ThisSlot.Slot | Should -BeExactly '2'
                $ThisSlot.Model | Should -BeExactly 'ST1206-0848-F6'
                $ThisSlot.Serial | Should -BeExactly '12235285636M'
                $ThisSlot.Firmware | Should -BeExactly '07.71.02.0005'
            }
            It "Should parse slot 2 option module 0 correctly" {
                $ThisSlot = $ParsedOutput[6]
                $ThisSlot.Slot | Should -BeExactly '2'
                $ThisSlot.Module | Should -BeExactly '0'
                $ThisSlot.Model | Should -BeExactly 'SOG1201-0112'
                $ThisSlot.Serial | Should -BeExactly '12070259595J'
            }
            It "Should parse slot 2 option module 3 correctly" {
                $ThisSlot = $ParsedOutput[7]
                $ThisSlot.Slot | Should -BeExactly '2'
                $ThisSlot.Module | Should -BeExactly '3'
                $ThisSlot.Model | Should -BeExactly 'SOK1208-0104'
                $ThisSlot.Serial | Should -BeExactly '12240548595L'
            }

            It "Should parse slot 3 correctly" {
                $ThisSlot = $ParsedOutput[8]
                $ThisSlot.Slot | Should -BeExactly '3'
                $ThisSlot.Model | Should -BeExactly 'ST1206-0848-F6'
                $ThisSlot.Serial | Should -BeExactly '12225145636M'
                $ThisSlot.Firmware | Should -BeExactly '07.71.02.0005'
            }
            It "Should parse slot 3 option module 0 correctly" {
                $ThisSlot = $ParsedOutput[9]
                $ThisSlot.Slot | Should -BeExactly '3'
                $ThisSlot.Module | Should -BeExactly '0'
                $ThisSlot.Model | Should -BeExactly 'SOG1201-0112'
                $ThisSlot.Serial | Should -BeExactly '12070250595J'
            }
            It "Should parse slot 3 option module 3 correctly" {
                $ThisSlot = $ParsedOutput[10]
                $ThisSlot.Slot | Should -BeExactly '3'
                $ThisSlot.Module | Should -BeExactly '3'
                $ThisSlot.Model | Should -BeExactly 'SOK1208-0104'
                $ThisSlot.Serial | Should -BeExactly '12240554595L'
            }

        }
        Context "SecureStack" {
            BeforeAll {
                $SampleOutput = $SecureStackOutput.Split([Environment]::NewLine)
                $ParsedOutput = Get-EosInventory -ConfigArray $SampleOutput
            }
            It "Should parse slot 1 correctly" {
                $ThisSlot = $ParsedOutput[0]
                $ThisSlot.Slot | Should -BeExactly '1'
                $ThisSlot.Model | Should -BeExactly 'A4H124-48P'
                $ThisSlot.Serial | Should -BeExactly '15060182915Y'
                $ThisSlot.Firmware | Should -BeExactly '06.71.03.0025'
            }
            It "Should parse slot 2 correctly" {
                $ThisSlot = $ParsedOutput[1]
                $ThisSlot.Slot | Should -BeExactly '2'
                $ThisSlot.Model | Should -BeExactly 'A4H124-48P'
                $ThisSlot.Serial | Should -BeExactly '12430191915R'
                $ThisSlot.Firmware | Should -BeExactly '06.71.03.0025'
            }
        }
        Context "SecureStack Single Unit" {
            BeforeAll {
                $SampleOutput = $SecureStackSingleUnitOutput.Split([Environment]::NewLine)
                $ParsedOutput = Get-EosInventory -ConfigArray $SampleOutput
            }
            It "Should parse slot 1 correctly" {
                $ThisSlot = $ParsedOutput[0]
                $ThisSlot.Slot | Should -BeExactly '1'
                $ThisSlot.Model | Should -BeExactly 'C3G124-48'
                $ThisSlot.Serial | Should -BeExactly '09380615225K'
                $ThisSlot.Firmware | Should -BeExactly '06.42.10.0016'
            }
        }
    }
}