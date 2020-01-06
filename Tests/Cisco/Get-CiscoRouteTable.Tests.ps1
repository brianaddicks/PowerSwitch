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

    $SampleRouteTable = @'
D EX    138.33.0.0/16 [170/28416] via 10.172.1.199, 5w2d, Vlan321
S       10.7.5.0/24 [1/0] via 10.7.0.5
L       10.7.0.6/32 is directly connected, Vlan700
S*   0.0.0.0/0 [1/0] via 10.172.1.1
'@
    $SampleConfigSecureStackRouterContext = $SampleConfigSecureStackRouterContext.Split([Environment]::NewLine)

    Describe "Get-CiscoRouteTable" {
        Context "Explicit Command" {
            $RouteTable = Get-CiscoRouteTable -ConfigArray $SampleRouteTable

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
                $RouteTable = Get-PsRouteTable -ConfigArray $SampleConfig7100 -PsSwitchType ExtremeEos

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
            $RouteTable = Get-EosRouteTable -ConfigArray $SampleConfigSecureStack

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
                $RouteTable = Get-PsRouteTable -ConfigArray $SampleConfigSecureStack -PsSwitchType ExtremeEos

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
            $RouteTable = Get-EosRouteTable -ConfigArray $SampleConfigSecureStackRouterContext

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
                $RouteTable = Get-PsRouteTable -ConfigArray $SampleConfigSecureStackRouterContext -PsSwitchType ExtremeEos

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