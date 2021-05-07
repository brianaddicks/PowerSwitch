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
        $ChassisConfig = @'
module 1 fi-sx6-8-port-10gig-fiber-module
module 2 fi-sx6-24-port-1gig-copper-poe-module
module 5 fi-sx6-24-port-1gig-fiber-module
module 9 fi-sx6-xl-0-port-management-module
module 10 fi-sx6-24-port-1gig-copper-poe-module
module 11 fi-sx6-48-port-gig-copper-poe-module
module 12 fi-sx-0-port-management-module
module 13 fi-sx6-24-port-100m-1g-fiber-module
!
hostname ChassisSwitch
'@
        $ChassisConfig = $ChassisConfig.Split([Environment]::NewLine)

        $StackConfig = @'
stack unit 1
  module 1 icx6610-48p-poe-port-management-module
  module 2 icx6610-qsfp-10-port-160g-module
  module 3 icx6610-8-port-10g-dual-mode-module
  priority 255
  stack-trunk 1/2/1 to 1/2/2
  stack-trunk 1/2/6 to 1/2/7
  stack-port 1/2/1 1/2/6
stack unit 2
  module 1 icx6610-48-port-management-module
  module 2 icx6610-qsfp-10-port-160g-module
  module 3 icx6610-8-port-10g-dual-mode-module
  stack-trunk 3/2/1 to 3/2/2
  stack-trunk 3/2/6 to 3/2/7
  stack-port 3/2/1 3/2/6
stack unit 3
  module 1 icx6450-24p-poe-port-management-module
  module 2 icx6450-sfp-plus-4port-40g-module
!
hostname StackSwitch
'@
        $StackConfig = $StackConfig.Split([Environment]::NewLine)
        ########################################################################
        #endregion dummydata
    }

    Describe "Get-BrocadeInventory" {

        #region chassis
        ########################################################################
        Context ChassisConfig {
            BeforeAll {
                $ParsedObject = Get-BrocadeInventory -ConfigArray $ChassisConfig
            }
            It "should return correct number of objects" {
                $ParsedObject.ChassisMember.Count | Should -BeExactly 8
                $ParsedObject.StackMember.Count | Should -BeExactly 0
                $ParsedObject.CopperPortTotal | Should -BeExactly 96
                $ParsedObject.FiberPortTotal | Should -BeExactly 56
                $ParsedObject.OneGigCopperPortCount | Should -BeExactly 96
                $ParsedObject.OneGigFiberCount | Should -BeExactly 48
                $ParsedObject.TenGigFiberCount | Should -BeExactly 8
                $ParsedObject.FortyGigFiberCount | Should -BeExactly 0
            }
            It "should return 'fi-sx6-8-port-10gig-fiber-module' blade correctly" {
                $ThisObject = $ParsedObject.ChassisMember[0]
                $ThisObject.Number | Should -BeExactly 1
                $ThisObject.Model | Should -BeExactly 'fi-sx6-8-port-10gig-fiber-module'
            }
            It "should return 'fi-sx6-24-port-1gig-copper-poe-module' blade correctly" {
                $ThisObject = $ParsedObject.ChassisMember[1]
                $ThisObject.Number | Should -BeExactly 2
                $ThisObject.Model | Should -BeExactly 'fi-sx6-24-port-1gig-copper-poe-module'
            }
            It "should return 'fi-sx6-24-port-1gig-fiber-module' blade correctly" {
                $ThisObject = $ParsedObject.ChassisMember[2]
                $ThisObject.Number | Should -BeExactly 5
                $ThisObject.Model | Should -BeExactly 'fi-sx6-24-port-1gig-fiber-module'
            }
            It "should return 'fi-sx6-xl-0-port-management-module' blade correctly" {
                $ThisObject = $ParsedObject.ChassisMember[3]
                $ThisObject.Number | Should -BeExactly 9
                $ThisObject.Model | Should -BeExactly 'fi-sx6-xl-0-port-management-module'
            }
            It "should return second 'fi-sx6-24-port-1gig-copper-poe-module' blade correctly" {
                $ThisObject = $ParsedObject.ChassisMember[4]
                $ThisObject.Number | Should -BeExactly 10
                $ThisObject.Model | Should -BeExactly 'fi-sx6-24-port-1gig-copper-poe-module'
            }
            It "should return second 'fi-sx6-48-port-gig-copper-poe-module' blade correctly" {
                $ThisObject = $ParsedObject.ChassisMember[5]
                $ThisObject.Number | Should -BeExactly 11
                $ThisObject.Model | Should -BeExactly 'fi-sx6-48-port-gig-copper-poe-module'
            }
            It "should return second 'fi-sx-0-port-management-module' blade correctly" {
                $ThisObject = $ParsedObject.ChassisMember[6]
                $ThisObject.Number | Should -BeExactly 12
                $ThisObject.Model | Should -BeExactly 'fi-sx-0-port-management-module'
            }
            It "should return second 'fi-sx6-24-port-100m-1g-fiber-module' blade correctly" {
                $ThisObject = $ParsedObject.ChassisMember[7]
                $ThisObject.Number | Should -BeExactly 13
                $ThisObject.Model | Should -BeExactly 'fi-sx6-24-port-100m-1g-fiber-module'
            }
        }
        ########################################################################
        #endregion chassis

        #region stack
        ########################################################################
        Context StackConfig {
            BeforeAll {
                $ParsedObject = Get-BrocadeInventory -ConfigArray $StackConfig
            }
            It "should return correct number of objects" {
                $ParsedObject.ChassisMember.Count | Should -BeExactly 0
                $ParsedObject.StackMember.Count | Should -BeExactly 8
                $ParsedObject.CopperPortTotal | Should -BeExactly 120
                $ParsedObject.FiberPortTotal | Should -BeExactly 28
                $ParsedObject.OneGigCopperPortCount | Should -BeExactly 120
                $ParsedObject.OneGigFiberCount | Should -BeExactly 0
                $ParsedObject.TenGigFiberCount | Should -BeExactly 20
                $ParsedObject.FortyGigFiberCount | Should -BeExactly 8
            }
            Context 'Stack Member 1' {
                It "should return 'icx6610-48p-poe-port-management-module' module correctly" {
                    $ThisObject = $ParsedObject.StackMember[0]
                    $ThisObject.Number | Should -BeExactly 1
                    $ThisObject.Module | Should -BeExactly 1
                    $ThisObject.Model | Should -BeExactly 'icx6610-48p-poe-port-management-module'
                }
                It "should return 'icx6610-qsfp-10-port-160g-module' module correctly" {
                    $ThisObject = $ParsedObject.StackMember[1]
                    $ThisObject.Number | Should -BeExactly 1
                    $ThisObject.Module | Should -BeExactly 2
                    $ThisObject.Model | Should -BeExactly 'icx6610-qsfp-10-port-160g-module'
                }
                It "should return 'icx6610-8-port-10g-dual-mode-module' module correctly" {
                    $ThisObject = $ParsedObject.StackMember[2]
                    $ThisObject.Number | Should -BeExactly 1
                    $ThisObject.Module | Should -BeExactly 3
                    $ThisObject.Model | Should -BeExactly 'icx6610-8-port-10g-dual-mode-module'
                }
            }
            Context 'Stack Member 2' {
                It "should return 'icx6610-48-port-management-module' module correctly" {
                    $ThisObject = $ParsedObject.StackMember[3]
                    $ThisObject.Number | Should -BeExactly 2
                    $ThisObject.Module | Should -BeExactly 1
                    $ThisObject.Model | Should -BeExactly 'icx6610-48-port-management-module'
                }
                It "should return 'icx6610-qsfp-10-port-160g-module' module correctly" {
                    $ThisObject = $ParsedObject.StackMember[4]
                    $ThisObject.Number | Should -BeExactly 2
                    $ThisObject.Module | Should -BeExactly 2
                    $ThisObject.Model | Should -BeExactly 'icx6610-qsfp-10-port-160g-module'
                }
                It "should return 'icx6610-8-port-10g-dual-mode-module' module correctly" {
                    $ThisObject = $ParsedObject.StackMember[5]
                    $ThisObject.Number | Should -BeExactly 2
                    $ThisObject.Module | Should -BeExactly 3
                    $ThisObject.Model | Should -BeExactly 'icx6610-8-port-10g-dual-mode-module'
                }
            }
            Context 'Stack Member 3' {
                It "should return 'icx6450-24p-poe-port-management-module' module correctly" {
                    $ThisObject = $ParsedObject.StackMember[6]
                    $ThisObject.Number | Should -BeExactly 3
                    $ThisObject.Module | Should -BeExactly 1
                    $ThisObject.Model | Should -BeExactly 'icx6450-24p-poe-port-management-module'
                }
                It "should return 'icx6450-sfp-plus-4port-40g-module' module correctly" {
                    $ThisObject = $ParsedObject.StackMember[7]
                    $ThisObject.Number | Should -BeExactly 3
                    $ThisObject.Module | Should -BeExactly 2
                    $ThisObject.Model | Should -BeExactly 'icx6450-sfp-plus-4port-40g-module'
                }
            }
        }
        ########################################################################
        #endregion stack
    }
}