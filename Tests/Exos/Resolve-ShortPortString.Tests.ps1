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

    Describe "Resolve-ShortPortString" -tag portstring {
        Context "Single Exos switch with stacking disabled" {
            BeforeEach {
                $PortList = @()
                $PortList += '1'
            }
            It "Should work for single port" {
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1'
            }
            It "Should work for two consecutive ports" {
                $PortList += '2'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1-2'
            }
            It "Should work for 3+ consecutive ports" {
                $PortList += '2'
                $PortList += '3'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1-3'
            }
            It "Should work for 2 nonconsecutive ports" {
                $PortList += '3'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1,3'
            }
            It "Should work for 3+ nonconsecutive ports" {
                $PortList += '3'
                $PortList += '5'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1,3,5'
            }
            It "Should work for 2 ranges of consecutive ports" {
                $PortList += '2'
                $PortList += '3'
                $PortList += '6'
                $PortList += '7'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1-3,6-7'
            }
            It "Should work for ranges, nonconsecutive ports, and a single port at the end" {
                $PortList += '2'
                $PortList += '3'
                $PortList += '5'
                $PortList += '7'
                $PortList += '8'
                $PortList += '11'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1-3,5,7-8,11'
            }
        }
        Context "Exos switch with stacking enabled" {
            BeforeEach {
                $PortList = @()
                $PortList += '1:1'
            }
            It "Should work for single port" {
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1'
            }
            It "Should work for two consecutive ports" {
                $PortList += '1:2'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1-2'
            }
            It "Should work for 3+ consecutive ports" {
                $PortList += '1:2'
                $PortList += '1:3'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1-3'
            }
            It "Should work for 2 nonconsecutive ports" {
                $PortList += '1:3'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1,1:3'
            }
            It "Should work for 3+ nonconsecutive ports" {
                $PortList += '1:3'
                $PortList += '1:5'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1,1:3,1:5'
            }
            It "Should work for 2 ranges of consecutive ports" {
                $PortList += '1:2'
                $PortList += '1:3'
                $PortList += '1:6'
                $PortList += '1:7'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1-3,1:6-7'
            }
            It "Should work for ranges, nonconsecutive ports, and a single port at the end" {
                $PortList += '1:2'
                $PortList += '1:3'
                $PortList += '1:5'
                $PortList += '1:7'
                $PortList += '1:8'
                $PortList += '1:11'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1-3,1:5,1:7-8,1:11'
            }
            It "Should work for 2 nonconsecutive ports on 2 stack members" {
                $PortList += '2:3'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1,2:3'
            }
            It "Should work for 2 ranges of consecutive ports on 2 stack members" {
                $PortList += '1:2'
                $PortList += '1:3'
                $PortList += '2:6'
                $PortList += '2:7'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1-3,2:6-7'
            }
            It "Should work for ranges, nonconsecutive ports, multiple stack members, and a single port at the end" {
                $PortList += '1:2'
                $PortList += '1:3'
                $PortList += '1:5'
                $PortList += '2:7'
                $PortList += '2:8'
                $PortList += '2:11'
                Resolve-ShortPortString $PortList Exos | Should -BeExactly '1:1-3,1:5,2:7-8,2:11'
            }
        }
    }
}