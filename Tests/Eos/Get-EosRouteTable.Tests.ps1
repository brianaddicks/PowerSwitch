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
        $SampleConfig7100 = @'
Switch(ro)->show ip route

IP Route Table for the base topology in VRF global
Codes: C-connected, S-static, R-RIP, B-BGP, O-OSPF, IA-OSPF interarea
        N1-OSPF NSSA external type 1, N2-OSPF NSSA external type 2
        E1-OSPF external type 1, E2-OSPF external type 2,
        i-IS-IS, L1-IS-IS level-1, L2-IS-IS level-2

S      0.0.0.0/0           [1/1]        via       10.88.192.254    vlan.0.143        310d01h19m55s
C      10.88.64.0/24       [0/0]        direct    10.88.64.1       vlan.0.143        310d01h19m43s
C      10.88.65.0/24       [0/0]        direct    10.88.65.1       vlan.0.142        310d01h19m43s
C      127.0.0.1/32        [0/0]        direct                     lo.0.1            310d01h20m41s

Number of routes = 4
Switch(ro)->
'@
        $SampleConfig7100 = $SampleConfig7100.Split([Environment]::NewLine)

        $SampleConfigSecureStack = @'
ltg-wst-cor-001(su)->show ip route

INET route table
Destination                   Gateway                       Flags    Use   If    Metric
0.0.0.0/0                     10.88.192.254                 UG       46332 rt8    5
10.88.64.0/24                 10.88.64.1                    UC       1433  rt1    5
10.88.64.1                    10.88.64.1                    UH       0     lo0    5
10.88.65.0/24                 10.88.65.1                    UC       44    rt2    5
10.88.65.1                    10.88.65.1                    UH       18    lo0    5
127.0.0.1                     127.0.0.1                     UH       16592317lo0    5

SecureStack(su)->router
'@
        $SampleConfigSecureStack = $SampleConfigSecureStack.Split([Environment]::NewLine)

        $SampleConfigSecureStackRouterContext = @'
#Router Configuration
router
enable
configure
interface vlan 64
ip address 10.88.64.1 255.255.255.0
no shutdown
exit
interface vlan 65
ip address 10.88.65.1 255.255.255.0
no shutdown
exit
exit
exit
exit
!
SecureStack(su)->router#show ip route

Codes: C - connected, S - static, R - RIP, O - OSPF, IA - OSPF interarea
       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2
       E1 - OSPF external type 1, E2 - OSPF external type 2
       E - EGP, i - IS-IS, L1 - IS-IS level-1, LS - IS-IS level-2
       * - candidate default, U - per user static route

*    0.0.0.0/0 [1/1] via 10.88.192.254, Vlan 192*    0.0.0.0/0 [1/1] via 10.88.192.254, Vlan 192
C    10.88.64.0/24 [0/0] directly connected, Vlan 64
C    10.88.65.0/24 [0/0] directly connected, Vlan 65
SecureStack(su)->router#
'@
        $SampleConfigSecureStackRouterContext = $SampleConfigSecureStackRouterContext.Split([Environment]::NewLine)
    }

    Describe "Get-EosRouteTable" {
        Context "7100 Config" {
            BeforeAll {
                $RouteTable = Get-EosRouteTable -ConfigArray $SampleConfig7100
            }
            It "Should find correct number of Routes" {
                $RouteTable.Count | Should -BeExactly 4
            }
            Context "Should report correct Route Table entries" {
                It "Should find Route 0.0.0.0/0 -> 10.88.192.254 (S)" {
                    $RouteTable[0].Destination | Should -BeExactly '0.0.0.0/0'
                    $RouteTable[0].NextHop | Should -BeExactly '10.88.192.254'
                    $RouteTable[0].Type | Should -BeExactly 'static'
                }
                It "Should find Route 10.88.64.0/24 -> 10.88.64.1 (C)" {
                    $RouteTable[1].Destination | Should -BeExactly '10.88.64.0/24'
                    $RouteTable[1].NextHop | Should -BeExactly '10.88.64.1'
                    $RouteTable[1].Type | Should -BeExactly 'connected'
                }
                It "Should find Route 10.88.65.0/24 -> 10.88.65.1 (C)" {
                    $RouteTable[2].Destination | Should -BeExactly '10.88.65.0/24'
                    $RouteTable[2].NextHop | Should -BeExactly '10.88.65.1'
                    $RouteTable[2].Type | Should -BeExactly 'connected'
                }
                It "Should find Route 127.0.0.1/32 -> null (S)" {
                    $RouteTable[3].Destination | Should -BeExactly '127.0.0.1/32'
                    $RouteTable[3].NextHop | Should -BeNullOrEmpty
                    $RouteTable[3].Type | Should -BeExactly 'connected'
                }
            }
            Describe "Get-PsRouteTable -PsSwitchType ExtremeEos" {
                BeforeAll {
                    $RouteTable = Get-PsRouteTable -ConfigArray $SampleConfig7100 -PsSwitchType ExtremeEos
                }
                It "Should find correct number of Routes" {
                    $RouteTable.Count | Should -BeExactly 4
                }
                Context "Should report correct Route Table entries" {
                    It "Should find Route 0.0.0.0/0 -> 10.88.192.254 (S)" {
                        $RouteTable[0].Destination | Should -BeExactly '0.0.0.0/0'
                        $RouteTable[0].NextHop | Should -BeExactly '10.88.192.254'
                        $RouteTable[0].Type | Should -BeExactly 'static'
                    }
                    It "Should find Route 10.88.64.0/24 -> 10.88.64.1 (C)" {
                        $RouteTable[1].Destination | Should -BeExactly '10.88.64.0/24'
                        $RouteTable[1].NextHop | Should -BeExactly '10.88.64.1'
                        $RouteTable[1].Type | Should -BeExactly 'connected'
                    }
                    It "Should find Route 10.88.65.0/24 -> 10.88.65.1 (C)" {
                        $RouteTable[2].Destination | Should -BeExactly '10.88.65.0/24'
                        $RouteTable[2].NextHop | Should -BeExactly '10.88.65.1'
                        $RouteTable[2].Type | Should -BeExactly 'connected'
                    }
                    It "Should find Route 127.0.0.1/32 -> null (S)" {
                        $RouteTable[3].Destination | Should -BeExactly '127.0.0.1/32'
                        $RouteTable[3].NextHop | Should -BeNullOrEmpty
                        $RouteTable[3].Type | Should -BeExactly 'connected'
                    }
                }
            }
        }
        Context "SecureStack Non-Router Context Config" {
            BeforeAll {
                $RouteTable = Get-EosRouteTable -ConfigArray $SampleConfigSecureStack
            }
            It "Should find correct number of Routes" {
                $RouteTable.Count | Should -BeExactly 3
            }
            Context "Should report correct Route Table entries" {
                It "Should find Route 0.0.0.0/0 -> 10.88.192.254 (S)" {
                    $RouteTable[0].Destination | Should -BeExactly '0.0.0.0/0'
                    $RouteTable[0].NextHop | Should -BeExactly '10.88.192.254'
                    $RouteTable[0].Type | Should -BeExactly 'static'
                }
                It "Should find Route 10.88.64.0/24 -> 10.88.64.1 (C)" {
                    $RouteTable[1].Destination | Should -BeExactly '10.88.64.0/24'
                    $RouteTable[1].NextHop | Should -BeExactly '10.88.64.1'
                    $RouteTable[1].Type | Should -BeExactly 'connected'
                }
                It "Should find Route 10.88.65.0/24 -> 10.88.65.1 (C)" {
                    $RouteTable[2].Destination | Should -BeExactly '10.88.65.0/24'
                    $RouteTable[2].NextHop | Should -BeExactly '10.88.65.1'
                    $RouteTable[2].Type | Should -BeExactly 'connected'
                }
            }
            Describe "Get-PsRouteTable -PsSwitchType ExtremeEos" {
                BeforeAll {
                    $RouteTable = Get-PsRouteTable -ConfigArray $SampleConfigSecureStack -PsSwitchType ExtremeEos
                }
                It "Should find correct number of Routes" {
                    $RouteTable.Count | Should -BeExactly 3
                }
                Context "Should report correct Route Table entries" {
                    It "Should find Route 0.0.0.0/0 -> 10.88.192.254 (S)" {
                        $RouteTable[0].Destination | Should -BeExactly '0.0.0.0/0'
                        $RouteTable[0].NextHop | Should -BeExactly '10.88.192.254'
                        $RouteTable[0].Type | Should -BeExactly 'static'
                    }
                    It "Should find Route 10.88.64.0/24 -> 10.88.64.1 (C)" {
                        $RouteTable[1].Destination | Should -BeExactly '10.88.64.0/24'
                        $RouteTable[1].NextHop | Should -BeExactly '10.88.64.1'
                        $RouteTable[1].Type | Should -BeExactly 'connected'
                    }
                    It "Should find Route 10.88.65.0/24 -> 10.88.65.1 (C)" {
                        $RouteTable[2].Destination | Should -BeExactly '10.88.65.0/24'
                        $RouteTable[2].NextHop | Should -BeExactly '10.88.65.1'
                        $RouteTable[2].Type | Should -BeExactly 'connected'
                    }
                }
            }
        }
        Context "SecureStack Router Context Config" {
            BeforeAll {
                $RouteTable = Get-EosRouteTable -ConfigArray $SampleConfigSecureStackRouterContext
            }
            It "Should find correct number of Routes" {
                $RouteTable.Count | Should -BeExactly 3
            }
            Context "Should report correct Route Table entries" {
                It "Should find Route 0.0.0.0/0 -> 10.88.192.254 (S)" {
                    $RouteTable[0].Destination | Should -BeExactly '0.0.0.0/0'
                    $RouteTable[0].NextHop | Should -BeExactly '10.88.192.254'
                    $RouteTable[0].Type | Should -BeExactly 'candidate default'
                }
                It "Should find Route 10.88.64.0/24 -> 10.88.64.1 (C)" {
                    $RouteTable[1].Destination | Should -BeExactly '10.88.64.0/24'
                    $RouteTable[1].NextHop | Should -BeExactly '10.88.64.1'
                    $RouteTable[1].Type | Should -BeExactly 'connected'
                }
                It "Should find Route 10.88.65.0/24 -> 10.88.65.1 (C)" {
                    $RouteTable[2].Destination | Should -BeExactly '10.88.65.0/24'
                    $RouteTable[2].NextHop | Should -BeExactly '10.88.65.1'
                    $RouteTable[2].Type | Should -BeExactly 'connected'
                }
            }
            Describe "Get-PsRouteTable -PsSwitchType ExtremeEos" {
                BeforeAll {
                    $RouteTable = Get-PsRouteTable -ConfigArray $SampleConfigSecureStackRouterContext -PsSwitchType ExtremeEos
                }
                It "Should find correct number of Routes" {
                    $RouteTable.Count | Should -BeExactly 3
                }
                Context "Should report correct Route Table entries" {
                    It "Should find Route 0.0.0.0/0 -> 10.88.192.254 (S)" {
                        $RouteTable[0].Destination | Should -BeExactly '0.0.0.0/0'
                        $RouteTable[0].NextHop | Should -BeExactly '10.88.192.254'
                        $RouteTable[0].Type | Should -BeExactly 'candidate default'
                    }
                    It "Should find Route 10.88.64.0/24 -> 10.88.64.1 (C)" {
                        $RouteTable[1].Destination | Should -BeExactly '10.88.64.0/24'
                        $RouteTable[1].NextHop | Should -BeExactly '10.88.64.1'
                        $RouteTable[1].Type | Should -BeExactly 'connected'
                    }
                    It "Should find Route 10.88.65.0/24 -> 10.88.65.1 (C)" {
                        $RouteTable[2].Destination | Should -BeExactly '10.88.65.0/24'
                        $RouteTable[2].NextHop | Should -BeExactly '10.88.65.1'
                        $RouteTable[2].Type | Should -BeExactly 'connected'
                    }
                }
            }
        }
    }
}