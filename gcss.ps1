[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'live')]
    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'processlog')]
    [string]$OutputPath,

    [Parameter(Mandatory = $True, Position = 1, ParameterSetName = 'live')]
    [string]$SeedIpAddress,

    [Parameter(Mandatory = $True, Position = 2, ParameterSetName = 'live')]
    [System.Management.Automation.PSCredential[]]
    [System.Management.Automation.Credential()]
    $Credential,

    [Parameter(Mandatory = $false, ParameterSetName = 'live')]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $AlternateCredential,

    [Parameter(Mandatory = $false, ParameterSetName = 'live')]
    [switch]
    $RefreshData,

    [Parameter(Mandatory = $false, ParameterSetName = 'processlog')]
    [switch]
    $ProcessLogFiles
)
ipmo ./PowerSwitch -Force -Verbose:$false
ipmo ../Gossh/Gossh -Force -Verbose:$false


# load existing data
$InventoryPath = Join-Path -Path $OutputPath -ChildPath 'inventory.json'
if ($RefreshData -or $ProcessLogFiles) {
    $Inventory = @()
} elseif (Test-Path -Path $InventoryPath) {
    $Inventory = Get-Content -Path $InventoryPath -Raw | ConvertFrom-Json
} else {
    $Inventory = @()
}

# log files
$LogFilePath = Join-Path $OutputPath -ChildPath 'logs'
if (Test-Path -Path $LogFilePath) {
    $LogFiles = Get-ChildItem $LogFilePath
} else {
    $CreateLogFolder = New-Item -Path $LogFilePath -ItemType Directory
    $LogFiles = @()
}

# remove inventory entries with missing log files
foreach ($ThisSwitch in $Inventory) {
    $ThisLogPath = Join-Path -Path $OutputPath -ChildPath 'logs' -AdditionalChildPath $ThisSwitch.File
    if (-not (Test-Path -Path $ThisLogPath)) {
        $Inventory = $Inventory | Where-Object { $_ -ne $ThisSwitch }
    }
}

# remove inventory for entries that are missing commands


$CiscoCommands = @(
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

# remove inventory for entries that are missing commands
$RequiredCommands = $CiscoCommands | ? { $_ -ne 'exit' }
foreach ($ThisSwitch in $Inventory) {
    Write-Verbose "Checking inv: $($ThisSwitch.File)"
    $ThisLogPath = Join-Path -Path $OutputPath -ChildPath 'logs' -AdditionalChildPath $ThisSwitch.File

    # remove entries missing logfiles
    if (-not (Test-Path -Path $ThisLogPath)) {
        $Inventory = $Inventory | Where-Object { $_ -ne $ThisSwitch }
    } else {
        $ThisOutput = Get-Content $ThisLogPath
    }

    foreach ($command in $RequiredCommands) {
        $CheckForCommand = $ThisOutput | Select-String -Pattern "$command`$"
        if (-not $CheckForCommand) {
            $Inventory = $Inventory | Where-Object { $_ -ne $ThisSwitch }
        }
    }
}

# ignore neighbors
$IgnoreNeighborRemotePortRx = '^(eth|vmnic|Port\s|FastEthernet\d+\/)\d+$'

# Gossh Setup
$GosshParams = @{}
$GosshParams.Credential = $Credential
$GosshParams.EnableCredential = $Credential
$GosshParams.DeviceType = 'CiscoSwitch'
$GosshParams.Command = $CiscoCommands

function Get-SwitchData {
    Param (
        [Parameter(Mandatory = $True, Position = 0,ParameterSetName = 'ip')]
        [string]$IpAddress,

        [Parameter(Mandatory = $True, Position = 0,ParameterSetName = 'logfile')]
        $LogFile
    )

    # Setup retun object
    $NewSwitch = "" | Select-Object File,SwitchType,HostConfig,AllNeighbors,InterestingNeighbors,IpInterfaces,Inventory

    if (-not $LogFile) {
        # get input using gossh
        try {
            $ThisOutput = Invoke-Gossh -Hostname $IpAddress @GosshParams
        } catch {
            switch -Regex ($_.Exception.Message) {
                'connection refused' {
                    Write-Warning "error connecting: connection refused"
                    $ThisOutput = "SSH Connection Refused by: $IpAddress"
                }
                'unable to authenticate' {
                    Write-Warning "error connecting: unable to authenticate"
                    if ($AlternateCredential) {
                        try {
                            $ThisOutput = Invoke-Gossh -Hostname $IpAddress -Credential $AlternateCredential -EnableCredential $AlternateCredential -DeviceType 'CiscoSwitch' -Command $CiscoCommands
                        } catch {
                            switch -Regex ($_.Exception.Message) {
                                'unable to authenticate' {
                                    $ThisOutput = "Unable to Authenticate with AlternateCredential: $IpAddress"
                                }
                                default {
                                    Throw $_
                                }
                            }
                        }
                    } else {
                        $ThisOutput = "Unable to Authenticate, No AlternateCredential Specified: $IpAddress"
                    }
                }
                'i/o timeout' {
                    $ThisOutput = "SSH Timeout: $IpAddress"
                }
                default {
                    Throw $_
                }
            }
        }
    } else {
        $ThisOutput = Get-Content $LogFile
    }

    # Setup PowerSwitch
    $PowerSwitchParams = @{}
    $PowerSwitchParams.ConfigArray = $ThisOutput

    # get PsSwitchType, this will be used for all subsquent commands
    try {
        $ThisSwitchType = Get-PsSwitchType @PowerSwitchParams
    } catch {
        Write-Warning "Could not get PsSwitchType: $IpAddress"
        $ThisSwitchType = $false
    }

    if ($ThisSwitchType) {
        $NewSwitch.SwitchType = $ThisSwitchType
        $PowerSwitchParams.PsSwitchType = $ThisSwitchType

        # get host config and use it to look for duplicates
        $ThisHostConfig = Get-PsHostConfig @PowerSwitchParams -ErrorAction Stop
        $NewSwitch.HostConfig = $ThisHostConfig

        $NewSwitch.AllNeighbors = Get-PsNeighbor @PowerSwitchParams
        $NewSwitch.IpInterfaces = Get-PsIpInterface @PowerSwitchParams
        $NewSwitch.Inventory = Get-PsInventory @PowerSwitchParams

        # get InterestingNeighbors, weeds out phones, esx, APs, etc
        $IgnoreNeighborRemotePortRx = '^(eth|vmnic|Port\s|FastEthernet\d+\/)\d+$'
        $NewSwitch.InterestingNeighbors = $NewSwitch.AllNeighbors | Where-Object { $_.RemotePort -notmatch $IgnoreNeighborRemotePortRx }

        if ($LogFile) {
            $LogFileName = Split-Path -Path $LogFile -Leaf
        } else {
            $LogFileName = $ThisHostConfig.Name + '-' + ($ThisHostConfig.IpAddress -replace '\/\d+','') + '.log'
        }
    } else {
        if ($LogFile) {
            $LogFileName = Split-Path -Path $LogFile -Leaf
        } else {
            $LogFileName = $IpAddress + '.log'
        }

        $BogusIpInterface = New-PsIpInterface -Name 'UNKNOWN'
        $BogusIpInterface.IpAddress = $IpAddress
        $NewSwitch.IpInterfaces = @($BogusIpInterface)
    }

    # log output to ./logs
    $ThisLogFilePath = Join-Path -Path $LogFilePath -ChildPath $LogFileName
    $ThisOutput | Out-File -FilePath $ThisLogFilePath
    $NewSwitch.File = $LogFileName

    $NewSwitch
}

function Get-UnknownNeighbors {
    $AllInterfaceIps = @()
    $AllNeighbors = @()

    foreach ($ThisSwitch in $Inventory) {
        foreach ($ThisInterface in $ThisSwitch.IpInterfaces) {
            foreach ($ThisIp in $ThisInterface.IpAddress) {
                $AllInterfaceIps += ($ThisIp -replace '\/\d+')
            }
        }
    }

    foreach ($ThisSwitch in $Inventory) {
        foreach ($ThisNeighbor in $ThisSwitch.InterestingNeighbors) {
            foreach ($ThisIp in $ThisNeighbor.IpAddress) {
                $AllNeighbors += $ThisIP
            }
        }
    }

    $AllNeighbors | Where-Object { $AllInterfaceIps -notcontains $_ } | Select-Object -Unique
}

# initial seed gathering
if ($Inventory.Count -eq 0 -and -not $ProcessLogFiles) {
    Write-Warning "Getting data for Seed: $SeedIpAddress"
    #$ThisOutput = Invoke-Gossh -Hostname $SeedIpAddress @GosshParams

    $ThisSwitch = Get-SwitchData -IpAddress $SeedIpAddress
    $Inventory += $ThisSwitch
}

$UnknownNeighbors = Get-UnknownNeighbors

do {
    $i = 0
    Write-Warning "Unknown Neighbors: $($UnknownNeighbors.Count)"
    foreach ($neighbor in $UnknownNeighbors) {
        $i++
        Write-Warning "Getting data for neighbor: $i/$($UnknownNeighbors.Count): $neighbor"
        $Inventory += Get-SwitchData -IpAddress $neighbor
    }
    $UnknownNeighbors = Get-UnknownNeighbors
} while ($UnknownNeighbors.Count -gt 0)


if ($ProcessLogFiles) {
    $i = 0
    foreach ($LogFile in $LogFiles) {
        $i++
        Write-Warning "$i/$($LogFiles.Count)"
        $Inventory += Get-SwitchData -LogFile $LogFile
    }
}


# output inventory
$Inventory | ConvertTo-Json -Depth 20 | Out-File -FilePath $InventoryPath -Force


# hardware inventory
$HardwareInventory = @()
foreach ($entry in $Inventory) {
    if ($entry.Inventory.Count -gt 0) {
        foreach ($inv in $entry.Inventory) {
            $New = "" | Select-Object File,IpAddress,Name,Slot,Model,PortCount
            $New.File = $entry.File
            $New.Name = $entry.HostConfig.Name
            $New.IpAddress = $entry.HostConfig.IpAddress
            $New.Slot = $inv.Slot
            if ($inv.Model -eq 'Unspecified') {
                $New.Model = $inv.Module
            } else {
                $New.Model = $inv.Model
            }
            $New.PortCount = $inv.PortCount

            $HardwareInventory += $new
        }
    } else {
        $New = "" | Select-Object File,IpAddress,Name,Slot,Model,PortCount
        $New.File = $entry.File
        $New.Name = $entry.HostConfig.Name
        $New.IpAddress = $entry.HostConfig.IpAddress
        $New.Slot = "UNKNOWN"
        $New.Model = "UNKNOWN"
        $New.PortCount = "UNKNOWN"

        $HardwareInventory += $new
    }
}