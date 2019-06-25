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

    $SampleConfig = @()
    $SampleConfig += 'IP Route Table for the base topology in VRF global'
    $SampleConfig += 'Codes: C-connected, S-static, R-RIP, B-BGP, O-OSPF, IA-OSPF interarea'
    $SampleConfig += '       N1-OSPF NSSA external type 1, N2-OSPF NSSA external type 2'
    $SampleConfig += '       E1-OSPF external type 1, E2-OSPF external type 2,'
    $SampleConfig += '       i-IS-IS, L1-IS-IS level-1, L2-IS-IS level-2'
    $SampleConfig += ''
    $SampleConfig += 'S      0.0.0.0/0           [1/1]        via       10.124.124.42    vlan.0.143        310d01h19m55s'
    $SampleConfig += 'C      10.124.124.43/31    [0/0]        direct    10.124.124.43    vlan.0.143        310d01h19m43s'
    $SampleConfig += 'C      10.124.142.0/24     [0/0]        direct    10.124.142.1     vlan.0.142        310d01h19m43s'
    $SampleConfig += 'C      127.0.0.1/32        [0/0]        direct                     lo.0.1            310d01h20m41s'

    Describe "Get-EosRouteTable" {
        $RouteTable = Get-EosRouteTable -ConfigArray $SampleConfig

        It "Should find correct number of Routes" {
            $RouteTable.Count | Should -BeExactly 4
        }
        Context "Should report correct Route Table entries" {
            It "Should find Route 0.0.0.0/0 -> 10.124.124.42 (S)" {
                $RouteTable[0].Destination | Should -BeExactly '0.0.0.0/0'
                $RouteTable[0].NextHop | Should -BeExactly '10.124.124.42'
                $RouteTable[0].Type | Should -BeExactly 'static'
            }
            It "Should find Route 10.124.124.43/31 -> 10.124.124.43 (C)" {
                $RouteTable[1].Destination | Should -BeExactly '10.124.124.43/31'
                $RouteTable[1].NextHop | Should -BeExactly '10.124.124.43'
                $RouteTable[1].Type | Should -BeExactly 'connected'
            }
            It "Should find Route 10.124.142.0/24 -> 10.124.142.1 (C)" {
                $RouteTable[2].Destination | Should -BeExactly '10.124.142.0/24'
                $RouteTable[2].NextHop | Should -BeExactly '10.124.142.1'
                $RouteTable[2].Type | Should -BeExactly 'connected'
            }
            It "Should find Route 127.0.0.1/32 -> null (S)" {
                $RouteTable[3].Destination | Should -BeExactly '127.0.0.1/32'
                $RouteTable[3].NextHop | Should -BeNullOrEmpty
                $RouteTable[3].Type | Should -BeExactly 'connected'
            }
        }
    }
    Describe "Get-PsRouteTable -PsSwitchType ExtremeEos" {
        $RouteTable = Get-PsRouteTable -ConfigArray $SampleConfig -PsSwitchType ExtremeEos

        It "Should find correct number of Routes" {
            $RouteTable.Count | Should -BeExactly 4
        }
        Context "Should report correct Route Table entries" {
            It "Should find Route 0.0.0.0/0 -> 10.124.124.42 (S)" {
                $RouteTable[0].Destination | Should -BeExactly '0.0.0.0/0'
                $RouteTable[0].NextHop | Should -BeExactly '10.124.124.42'
                $RouteTable[0].Type | Should -BeExactly 'static'
            }
            It "Should find Route 10.124.124.43/31 -> 10.124.124.43 (C)" {
                $RouteTable[1].Destination | Should -BeExactly '10.124.124.43/31'
                $RouteTable[1].NextHop | Should -BeExactly '10.124.124.43'
                $RouteTable[1].Type | Should -BeExactly 'connected'
            }
            It "Should find Route 10.124.142.0/24 -> 10.124.142.1 (C)" {
                $RouteTable[2].Destination | Should -BeExactly '10.124.142.0/24'
                $RouteTable[2].NextHop | Should -BeExactly '10.124.142.1'
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