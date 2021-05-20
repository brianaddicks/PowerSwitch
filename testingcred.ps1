[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True, Position = 1, ParameterSetName = 'live')]
    [string]$IpAddress,

    [Parameter(Mandatory = $True, Position = 2, ParameterSetName = 'live')]
    [System.Management.Automation.PSCredential[]]
    $Credential,

    [Parameter(Mandatory = $True, Position = 2, ParameterSetName = 'live')]
    [System.Management.Automation.PSCredential[]]
    $EnableCredential
)

ipmo ./PowerSwitch -Force -Verbose:$false

$GosshParams = @{}
$GosshParams.Hostname = $IpAddress
$GosshParams.DeviceType = 'CiscoSwitch'
$GosshParams.Command = @(
    'enable'
    'exit'
)

# check for enable
:logincred foreach ($loginCred in $Credential) {
    $GosshParams.Credential = $loginCred
    $EnableCredCounter = 0
    :enablecred foreach ($enableCred in $EnableCredential) {
        $EnableCredCounter++
        $GosshParams.Command = @(
            'enable'
            $enableCred.GetNetworkCredential().Password
            'exit'
        )
        #$GosshParams.EnableCredential = $enableCred

        try {
            $ThisOutput = Invoke-Gossh @GosshParams
            if ($ThisOutput -match '% Access denied') {
                Write-Warning "Enable credential failed: $EnableCredCounter/$($EnableCredential.Count)"
                continue enablecred
            }
            break logincred
        } catch {
            switch -Regex ($_.Exception.Message) {
                'connection refused' {
                    Write-Warning "error connecting: connection refused"
                    $ThisOutput = "SSH Connection Refused by: $($GosshParams.Hostname)"
                    break logincred
                }
                'i/o timeout' {
                    $ThisOutput = "SSH Timeout: $($GosshParams.Hostname)"
                    break logincred
                }
                'unable to authenticate' {
                    $ThisOutput = "Unable to authenticate: $($GosshParams.Hostname)"
                    continue logincred
                }
                default {
                    Throw $_
                }
            }
        }
    }
}

$EnableSuccess = $ThisOutput -match '#exit'

if ($EnableSuccess.Count -gt 1) {
    Throw "enable didn't work"
    # enable didn't work for some reason
} else {
    $GosshParams.Command = @(
        'terminal length 0'
        'show version'
        'show module'
        'show cdp neighbors detail'
        'show int status'
        'show ip route'
        'show ip interface brief'
        'show etherchannel summary'
        'show spanning-tree'
        'show power inline'
        'show inventory'
        'show vlan'
        'show run'
        'exit'
    )
    $ThisOutput = Invoke-Gossh @GosshParams
}