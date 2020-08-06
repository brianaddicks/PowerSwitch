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
        $SampleRouteTable = @'
S*   0.0.0.0/0 [1/0] via 10.88.192.254
L       10.88.64.0/24 is directly connected, Vlan88
D EX    10.88.65.0/24 [170/28416] via 10.88.65.1, 5w2d, Vlan321
S       192.0.10.0/24 [1/0] via 10.88.192.253
'@
        $SampleRouteTable = $SampleRouteTable.Split([Environment]::NewLine)
    }

    Describe "Get-CiscoRouteTable" {
        Context "Explicit Command" {
            BeforeAll {
                $RouteTable = Get-CiscoRouteTable -ConfigArray $SampleRouteTable
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
                It "Should find Route 10.88.64.0/24 -> 10.88.64.1 (L)" {
                    $RouteTable[1].Destination | Should -BeExactly '10.88.64.0/24'
                    $RouteTable[1].NextHop | Should -BeNullOrEmpty
                    $RouteTable[1].Type | Should -BeExactly 'local'
                }
                It "Should find Route 10.88.65.0/24 -> 10.88.65.1 (D EX)" {
                    $RouteTable[2].Destination | Should -BeExactly '10.88.65.0/24'
                    $RouteTable[2].NextHop | Should -BeExactly '10.88.65.1'
                    $RouteTable[2].Type | Should -BeExactly 'EIGRP external'
                }
                It "Should find Route 192.0.10.0/24 -> 10.88.192.253 (S)" {
                    $RouteTable[3].Destination | Should -BeExactly '192.0.10.0/24'
                    $RouteTable[3].NextHop | Should -BeExactly '10.88.192.253'
                    $RouteTable[3].Type | Should -BeExactly 'static'
                }
            }
            Describe "Get-PsRouteTable -PsSwitchType Cisco" {
                BeforeAll {
                    $RouteTable = Get-PsRouteTable -ConfigArray $SampleRouteTable -PsSwitchType Cisco
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
                    It "Should find Route 10.88.64.0/24 -> 10.88.64.1 (L)" {
                        $RouteTable[1].Destination | Should -BeExactly '10.88.64.0/24'
                        $RouteTable[1].NextHop | Should -BeNullOrEmpty
                        $RouteTable[1].Type | Should -BeExactly 'local'
                    }
                    It "Should find Route 10.88.65.0/24 -> 10.88.65.1 (D EX)" {
                        $RouteTable[2].Destination | Should -BeExactly '10.88.65.0/24'
                        $RouteTable[2].NextHop | Should -BeExactly '10.88.65.1'
                        $RouteTable[2].Type | Should -BeExactly 'EIGRP external'
                    }
                    It "Should find Route 192.0.10.0/24 -> 10.88.192.253 (S)" {
                        $RouteTable[3].Destination | Should -BeExactly '192.0.10.0/24'
                        $RouteTable[3].NextHop | Should -BeExactly '10.88.192.253'
                        $RouteTable[3].Type | Should -BeExactly 'static'
                    }
                }
            }
        }
    }
}