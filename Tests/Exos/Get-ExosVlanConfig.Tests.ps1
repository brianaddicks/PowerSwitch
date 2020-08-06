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
        $SampleConfig = @()
        $SampleConfig += '#'
        $SampleConfig += '# Module vlan configuration.'
        $SampleConfig += '#'
        $SampleConfig += 'create vlan "SampleVlan1"'
        $SampleConfig += 'configure vlan SampleVlan1 tag 2'
        $SampleConfig += 'configure vlan SampleVlan1 add ports 1:1,2:1-3 tagged'
        $SampleConfig += 'configure vlan SampleVlan1 add ports 1,3 untagged'
        $SampleConfig += 'create vlan "SampleVlan2"'
        $SampleConfig += 'configure vlan SampleVlan2 tag 3'
        $SampleConfig += 'create vlan "SampleVlan3"'
        $SampleConfig += 'configure vlan SampleVlan3 tag 4'
        $SampleConfig += ''
        $SampleConfig += '#'

        $VlanConfig = Get-ExosVlanConfig -ConfigArray $SampleConfig
    }

    Describe "Get-ExosVlanConfig" {
        It "Should find correct number of Vlans" {
            $VlanConfig.Count | Should -BeExactly 4
        }
        Context "Should find correct Vlan IDs" {
            It "Should find Vlan 1" {
                $VlanConfig[0].Id | Should -BeExactly 1
            }
            It "Should find Vlan 2" {
                $VlanConfig[1].Id | Should -BeExactly 2
            }
            It "Should find Vlan 3" {
                $VlanConfig[2].Id | Should -BeExactly 3
            }
            It "Should find Vlan 4" {
                $VlanConfig[3].Id | Should -BeExactly 4
            }
        }
        Context "Should find correct Vlan Names" {
            It "Vlan 1 should be named Default" {
                $VlanConfig[0].Name | Should -BeExactly 'Default'
            }
            It "Vlan 2 should be named SampleVlan1" {
                $VlanConfig[1].Name | Should -BeExactly 'SampleVlan1'
            }
            It "Vlan 3 should be named SampleVlan2" {
                $VlanConfig[2].Name | Should -BeExactly 'SampleVlan2'
            }
            It "Vlan 4 should be named SampleVlan3" {
                $VlanConfig[3].Name | Should -BeExactly 'SampleVlan3'
            }
        }
        Context "Should map ports to Vlans properly" {
            It "SampleVlan1 should have port 1 untagged" {
                $VlanConfig[1].UntaggedPorts | Should -Contain '1'
            }
            It "SampleVlan1 should have port 1 untagged" {
                $VlanConfig[1].UntaggedPorts | Should -Contain '3'
            }
            It "SampleVlan1 should have port 1:1 tagged" {
                $VlanConfig[1].TaggedPorts | Should -Contain '1:1'
            }
            It "SampleVlan1 should have port 2:1 tagged" {
                $VlanConfig[1].TaggedPorts | Should -Contain '2:1'
            }
            It "SampleVlan1 should have port 2:2 tagged" {
                $VlanConfig[1].TaggedPorts | Should -Contain '2:2'
            }
            It "SampleVlan1 should have port 2:3 tagged" {
                $VlanConfig[1].TaggedPorts | Should -Contain '2:3'
            }
        }
    }
}