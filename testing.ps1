[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
    [string]$ConfigPath,

    [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
    [array]$ConfigArray
)
ipmo ./PowerSwitch -Force -Verbose:$false

Get-EosInventoryFromConfig -ConfigPath $ConfigPath

<#
$Files = gci $ConfigPath -File | ? { $_.BaseName -notmatch '_route$'}
#$Files = $Files[0..4]
$ReturnArray = @()
$i = 0

#$Files = gci $ConfigPath -File | ? { $_.BaseName -match '^\d+\.\d+\.\d+\.\d+$'}

foreach ($file in $Files) {
    $i++
    Write-Warning "$i/$($Files.Count): $($file.Name)"

    $ThisConfigArray = gc $file
    $PsParams = @{}
    $PsParams.ConfigArray = $ThisConfigArray
    $HostConfig = Get-CiscoHostConfig @PsParams
    $TimeConfig = Get-CiscoTimeConfig @PsParams
    $MgmtConfig = Get-CiscoMgmtConfig @PsParams
    $StpConfig = Get-CiscoSpantreeConfig @PsParams

    # new object
    $NewObject = "" | Select-Object LogFile,Name,IpAddress,
        SntpServer,
        SshEnabled,WebviewEnabled,
        RadiusServer,
        StpEnabled,StpMode,StpPriority,
        DhcpSnoopingEnabled,
        ArpInspectionEnabled,
        PortAuthenticationEnabled

    $ReturnArray += $NewObject

    # HostConfig
    $NewObject.LogFile = $file.Name
    $NewObject.Name = $HostConfig.Name
    $NewObject.IpAddress = $HostConfig.IpAddress

    # TimeConfig
    $NewObject.SntpServer = ($TimeConfig.SntpServer | Sort-Object) -join ','

    # MgmtConfig
    #$NewObject.TelnetEnabled = $MgmtConfig.TelnetEnabled # not reliable
    $NewObject.SshEnabled = $MgmtConfig.SshEnabled
    $NewObject.WebviewEnabled = $MgmtConfig.WebviewEnabled

    # StpConfig
    $NewObject.StpEnabled = $StpConfig.Enabled
    $NewObject.StpMode = $StpConfig.Mode
    $NewObject.StpPriority = $StpConfig.Priority

    # Know Disabled
    $NewObject.DhcpSnoopingEnabled = $false
    $NewObject.ArpInspectionEnabled = $false
    $NewObject.PortAuthenticationEnabled = $false
}

$ReturnArray #>