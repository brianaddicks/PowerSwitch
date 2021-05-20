[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'live')]
    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'processlog')]
    [string]$OutputPath,

    [Parameter(Mandatory = $True, Position = 1, ParameterSetName = 'live')]
    [string]$SeedIpAddress,

    [Parameter(Mandatory = $True, Position = 2, ParameterSetName = 'live')]
    [System.Management.Automation.PSCredential[]]
    $Credential,

    [Parameter(Mandatory = $false, ParameterSetName = 'live')]
    [System.Management.Automation.PSCredential[]]
    $EnableCredential,

    [Parameter(Mandatory = $false, ParameterSetName = 'live')]
    [switch]
    $RefreshData,

    [Parameter(Mandatory = $false, ParameterSetName = 'processlog')]
    [switch]
    $ProcessLogFiles
)
ipmo ./PowerSwitch -Force -Verbose:$false
ipmo ../Gossh/Gossh -Force -Verbose:$false

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

#region setup inventory
########################################################################

# load existing data
$InventoryPath = Join-Path -Path $OutputPath -ChildPath 'inventory.json'
if ($RefreshData) {
    Write-Verbose "RefreshData specified, clearing inventory file"
    $Inventory = @()
} elseif (Test-Path -Path $InventoryPath) {
    Write-Verbose "Inventory Exists, loading it"
    $Inventory = @(Get-Content -Path $InventoryPath -Raw | ConvertFrom-Json)
} else {
    Write-Verbose "No Inventory file found, creating empty array"
    $Inventory = @()
}

# log files
$LogFilePath = Join-Path $OutputPath -ChildPath 'logs'
if (Test-Path -Path $LogFilePath) {
    Write-Verbose "Log directory exists, loading exisitng log files"
    $LogFiles = Get-ChildItem $LogFilePath
} else {
    Write-Verbose "No Log directory, creating directory..."
    $CreateLogFolder = New-Item -Path $LogFilePath -ItemType Directory
    $LogFiles = @()
}

# remove inventory entries with missing log files
Write-Verbose "Removing entries from Inventory if log file does not exist"
foreach ($ThisSwitch in $Inventory) {
    $ThisLogPath = Join-Path -Path $OutputPath -ChildPath 'logs' -AdditionalChildPath $ThisSwitch.File
    $ThisRouteLogPath = $ThisLogPath -replace '\.log$','_route.log'

    if (-not (Test-Path -Path $ThisLogPath)) {
        Write-Verbose "No Log, removing $($ThisSwitch.File) from Inventory"
        $Inventory = $Inventory | Where-Object { $_ -ne $ThisSwitch }
    }

    if (-not (Test-Path -Path $ThisRouteLogPath)) {
        Write-Verbose "No Route Log, removing $($ThisSwitch.File) from Inventory"
        $Inventory = $Inventory | Where-Object { $_ -ne $ThisSwitch }
    }
}

# add log files not already in inventory
$LogsNotInInventory = $LogFiles | Where-Object { $_.Name -notmatch '_route.log' -and $Inventory.File -notcontains $_.Name }
foreach ($logFile in $LogsNotInInventory) {
    $NewSwitch = "" | Select-Object File,SwitchType,HostConfig,AllNeighbors,InterestingNeighbors,IpInterfaces,Inventory,Error
    $NewSwitch.File = $logFile.Name
    $Inventory += $NewSwitch
}


# remove inventory for entries that are missing commands
$RequiredCommands = $CiscoCommands | Where-Object { $_ -ne 'exit' }
Write-Verbose "Checking log files for all required commands"
foreach ($ThisSwitch in $Inventory) {
    Write-Verbose "Checking inv: $($ThisSwitch.File)"
    $ThisLogPath = Join-Path -Path $OutputPath -ChildPath 'logs' -AdditionalChildPath $ThisSwitch.File
    $ThisRouteLogPath = $ThisLogPath -replace '\.log$','_route.log'

    $ThisOutput = Get-Content $ThisLogPath
    $ThisOutput += Get-Content $ThisRouteLogPath


    foreach ($command in $RequiredCommands) {
        $CheckForCommand = $ThisOutput | Select-String -Pattern "(>|#)\s*$command`$"
        if (-not $CheckForCommand) {
            Write-Verbose "Log file missing command: $($ThisSwitch.File): $command"
            $Inventory = $Inventory | Where-Object { $_ -ne $ThisSwitch }
        }
    }
}

########################################################################
#endregion setup inventory

function Get-DiscoveryInfo {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 1)]
        [string]$IpAddress,

        [Parameter(Mandatory = $True, Position = 2)]
        [System.Management.Automation.PSCredential[]]
        $Credential,

        [Parameter(Mandatory = $True, Position = 2)]
        [System.Management.Automation.PSCredential[]]
        $EnableCredential,

        [Parameter(Mandatory = $True, Position = 4)]
        [string[]]
        $Command
    )

    $ReturnObject = "" | Select-Object Output,RouteOutput

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
                    #Write-Warning "Enable credential failed: $EnableCredCounter/$($EnableCredential.Count)"
                    continue enablecred
                }
                break logincred
            } catch {
                switch -Regex ($_.Exception.Message) {
                    'connection refused' {
                        #Write-Warning "error connecting: connection refused"
                        $ThisOutput = "ERROR: SSH Connection Refused by: $($GosshParams.Hostname)"
                        break logincred
                    }
                    'timeout' {
                        $ThisOutput = "ERROR: SSH Timeout: $($GosshParams.Hostname)"
                        break logincred
                    }
                    'unable to authenticate' {
                        $ThisOutput = "ERROR: Unable to authenticate: $($GosshParams.Hostname)"
                        continue logincred
                    }
                    'connection reset by peer' {
                        $ThisOutput = "ERROR: connection reset by peer: $($GosshParams.Hostname)"
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

    if ($ThisOutput -match '^ERROR:') {
        $ReturnObject.Output = $ThisOutput
    } else {
        if ($EnableSuccess.Count -ne 1) {
            Throw "enable didn't work"
            # enable didn't work for some reason
        } else {
            $EnableCommand = @(
                'enable'
                $enableCred.GetNetworkCredential().Password
            )

            $AllCommands = $EnableCommand + $Command
            if ($AllCommands -match 'show ip route') {
                $TheseCommands = $AllCommands -ne 'show ip route'
            }
            $GosshParams.Command = $TheseCommands
            $ReturnObject.Output = Invoke-Gossh @GosshParams

            # route output
            if ($AllCommands -match 'show ip route') {
                $GosshParams.Command = @(
                    'terminal length 0'
                    'enable'
                    $enableCred.GetNetworkCredential().Password
                    'show ip route'
                    'exit'
                )
                try {
                    $ReturnObject.RouteOutput = Invoke-Gossh @GosshParams
                } catch {
                    switch -Regex ($_.Exception.Message) {
                        'connection refused' {
                            #Write-Warning "error connecting: connection refused"
                            $ThisOutput = "ERROR: SSH Connection Refused by: $($GosshParams.Hostname)"
                            break logincred
                        }
                        'timeout' {
                            $ThisOutput = "ERROR: SSH Timeout: $($GosshParams.Hostname)"
                            break logincred
                        }
                        'unable to authenticate' {
                            $ThisOutput = "ERROR: Unable to authenticate: $($GosshParams.Hostname)"
                            continue logincred
                        }
                        'connection reset by peer' {
                            $ThisOutput = "ERROR: connection reset by peer: $($GosshParams.Hostname)"
                            continue logincred
                        }
                        default {
                            Throw $_
                        }
                    }
                }
            }
        }
    }

    $ReturnObject
}

function Get-UnknownNeighbors {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 1)]
        [array]$Inventory
    )

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

function Resolve-SwitchOutput {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [array]$SwitchOutput,

        [Parameter(Mandatory = $True, Position = 1)]
        [AllowNull()]
        [array]$RouteOutput,

        [Parameter(Mandatory = $True, Position = 2)]
        [string]$IpAddress,

        [Parameter(Mandatory = $false)]
        [switch]$IsLogFile
    )

    $NewSwitch = "" | Select-Object File,SwitchType,HostConfig,AllNeighbors,InterestingNeighbors,IpInterfaces,Inventory,Error
    $PowerSwitchParams = @{}
    $PowerSwitchParams.ConfigArray = $SwitchOutput

    # get PsSwitchType, this will be used for all subsquent commands
    try {
        $ThisSwitchType = Get-PsSwitchType @PowerSwitchParams
    } catch {
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
    } else {
        $BogusIpInterface = New-PsIpInterface -Name 'UNKNOWN'
        $BogusIpInterface.IpAddress = $IpAddress
        $NewSwitch.IpInterfaces = @($BogusIpInterface)
    }

    # log errors
    $ErrorRx = [regex] 'ERROR:\s+(.+?):'
    $ErrorMatch = $ErrorRx.Match($SwitchOutput)
    if ($ErrorMatch.Success) {
        $NewSwitch.Error = $ErrorMatch.Groups[1].Value
    }

    $NewSwitch
}

function Write-LogFiles {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [array]$SwitchOutput,

        [Parameter(Mandatory = $True)]
        [AllowNull()]
        [array]$RouteOutput,

        [Parameter(Mandatory = $True)]
        [AllowEmptyString()]
        [string]$Hostname,

        [Parameter(Mandatory = $True)]
        [string]$IpAddress,

        [Parameter(Mandatory = $True)]
        [string]$LogPath
    )

    if (!(Test-Path -Path $LogPath -PathType Container)) {
        Throw 'Invalid LogPath'
    }

    $LogFileName = ''

    # prepend hostname to logfilename if provided
    if ($Hostname) {
        $LogFileName += $Hostname + '_'
    }

    # add ip address
    $LogFileName += $IpAddress

    # Setup RouteLogFileName
    $RouteLogFileName = $LogFileName + '_route'

    # add extension
    $LogFileName += '.log'
    $RouteLogFileName += '.log'

    # setup paths
    $LogFilePath = Join-Path -Path $LogPath -ChildPath $LogFileName
    $RouteLogFilePath = Join-Path -Path $LogPath -ChildPath $RouteLogFileName

    $ReturnObject = "" | Select-Object LogFilePath,RouteLogFilePath
    $ReturnObject.LogFilePath = $LogFilePath
    $ReturnObject.RouteLogFilePath = $RouteLogFilePath

    $SwitchOutput | Out-File -FilePath $LogFilePath -Verbose
    $RouteOutput | Out-File -FilePath $RouteLogFilePath

    $ReturnObject
}


# initial seed gathering
$SeedInInventory = $Inventory | ? { $_.File -match "$SeedIpAddress`.log" }
if ($SeedInInventory.Count -eq 0 -and -not $ProcessLogFiles) {
    Write-Warning "Getting data for Seed: $SeedIpAddress"
    #$ThisOutput = Invoke-Gossh -Hostname $SeedIpAddress @GosshParams
    $DiscoveryParams = @{}
    $DiscoveryParams.IpAddress = $SeedIpAddress
    $DiscoveryParams.Credential = $Credential
    $DiscoveryParams.EnableCredential = $EnableCredential
    $DiscoveryParams.Command = $CiscoCommands

    $DiscoveryData = Get-DiscoveryInfo @DiscoveryParams
    $ThisSwitch = Resolve-SwitchOutput $DiscoveryData.Output $DiscoveryData.RouteOutput $SeedIpAddress

    $LogFileParams = @{}
    $LogFileParams.SwitchOutput = $DiscoveryData.Output
    $LogFileParams.RouteOutput = $DiscoveryData.RouteOutput
    $LogFileParams.Hostname = $ThisSwitch.HostConfig.Name
    $LogFileParams.IpAddress = $SeedIpAddress
    $LogFileParams.LogPath = $LogFilePath

    $LogFiles = Write-LogFiles @LogFileParams

    $ThisSwitch.File = Split-Path -Path $LogFiles.LogFilePath -Leaf

    $Inventory += $ThisSwitch
}

$UnknownNeighbors = Get-UnknownNeighbors -Inventory $Inventory

if (-not $ProcessLogFiles) {
    do {
        $i = 0
        Write-Warning "Unknown Neighbors: $($UnknownNeighbors.Count)"
        foreach ($neighbor in $UnknownNeighbors) {
            $i++
            Write-Warning "Getting data for neighbor: $i/$($UnknownNeighbors.Count): $neighbor"
            $DiscoveryParams.IpAddress = $neighbor
            if ($neighbor -eq '10.1.0.238') {
                $DiscoveryParams.Command = $DiscoveryParams.Command -replace 'show ip route','show ip route | inc ateway'
            }

            $InventoryLookup = $Inventory | Where-Object { $_.File -match "-$neighbor`.log" }
            if ($InventoryLookup) {
                Write-Warning "Log File Found, Skipping: $neighbor"
                $ThisLogFile = Join-Path -Path $LogFilePath -ChildPath $InventoryLookup.File
                $ThisRouteLogFile = Join-Path -Path $LogFilePath -ChildPath ($InventoryLookup.File -replace '\.log','_route\.log')
                $DiscoveryData = "" | Select-Object Output,RouteOutput
                $DiscoveryData.Output = Get-Content -Path $ThisLogFile
                $DiscoveryData.RouteOutput = Get-Content -Path $ThisRouteLogFile
            } else {
                Write-Warning "No Log File Found, Attempting to connect: $neighbor"
                $DiscoveryData = Get-DiscoveryInfo @DiscoveryParams
            }

            # reset after 238
            $DiscoveryParams.Command = $CiscoCommands

            if ($InventoryLookup) {
                $Inventory += Resolve-SwitchOutput $DiscoveryData.Output $DiscoveryData.RouteOutput $neighbor -IsLogFile
            } else {
                $ThisSwitch = Resolve-SwitchOutput $DiscoveryData.Output $DiscoveryData.RouteOutput $neighbor

                $LogFileParams = @{}
                $LogFileParams.SwitchOutput = $DiscoveryData.Output
                $LogFileParams.RouteOutput = $DiscoveryData.RouteOutput
                $LogFileParams.Hostname = $ThisSwitch.HostConfig.Name
                $LogFileParams.IpAddress = $neighbor
                $LogFileParams.LogPath = $LogFilePath

                $LogFiles = Write-LogFiles @LogFileParams

                $ThisSwitch.File = Split-Path -Path $LogFiles.LogFilePath -Leaf

                $Inventory += $ThisSwitch
            }
        }
        $UnknownNeighbors = Get-UnknownNeighbors -Inventory $Inventory
    } while ($UnknownNeighbors.Count -gt 0)
}

$Ipv4Rx = [regex] '((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'

$InventoryWithoutErrors = $Inventory | Where-Object { -not $_.Error }
$NewInventory = @()
if ($ProcessLogFiles) {
    Write-Verbose "Processing Log files"
    $i = 0
    foreach ($ThisSwitch in $InventoryWithoutErrors) {
        $i++
        Write-Warning "Processing Log files $i/$($InventoryWithoutErrors.Count): $($ThisSwitch.File)"
        $ThisLogPath = Join-Path -Path $OutputPath -ChildPath 'logs' -AdditionalChildPath $ThisSwitch.File
        $ThisRouteLogPath = $ThisLogPath -replace '\.log$','_route.log'
        $ThisIpAddress = $Ipv4Rx.Match($ThisSwitch.File).Value
        $ThisOutput = Get-Content -Path $ThisLogPath
        $ThisRouteOutput = Get-Content -Path $ThisRouteLogPath

        $ThisNewSwitch = Resolve-SwitchOutput $ThisOutput $ThisRouteOutput $ThisIpAddress -IsLogFile
        $ThisNewSwitch.File = $ThisSwitch.File
        $NewInventory += $ThisNewSwitch
    }
}

if ($NewInventory.Count -gt 0) {
    $Inventory = $NewInventory
}

# output inventory
$Inventory | ConvertTo-Json -Depth 20 | Out-File -FilePath $InventoryPath -Force