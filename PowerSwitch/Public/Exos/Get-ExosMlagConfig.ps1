function Get-ExosMlagConfig {
    [CmdletBinding(DefaultParametersetName = "path")]

    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'path')]
        [string]$ConfigPath,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'array')]
        [array]$ConfigArray
    )

    # It's nice to be able to see what cmdlet is throwing output isn't it?
    $VerbosePrefix = "Get-ExosMlagConfig:"

    # Check for path and import
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            $LoopArray = Get-Content $ConfigPath
        }
    } else {
        $LoopArray = $ConfigArray
    }

    # Setup return Array
    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
    $ReturnObject = [MlagConfig]::new()

    $TotalLines = $LoopArray.Count
    $i = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down

    # The following Rx will be ignored
    $IgnoreRx = @(
        '^#$'
    )

    :fileloop foreach ($entry in $LoopArray) {
        $i++

        # Write progress bar, we're only updating every 1000ms, if we do it every line it takes forever

        if ($StopWatch.Elapsed.TotalMilliseconds -ge 1000) {
            $PercentComplete = [math]::truncate($i / $TotalLines * 100)
            Write-Progress -Activity "$VerbosePrefix Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
            $StopWatch.Reset()
            $StopWatch.Start()
        }

        if ($entry -eq "") { continue }

        ###########################################################################################
        # Check for the Section

        $EvalParams = @{}
        $EvalParams.StringToEval = $entry.Trim()

        $EvalParams.Regex = [regex] "^#\ Module\ vsm\ configuration"
        $Eval = Get-RegexMatch @EvalParams
        if ($Eval) {
            Write-Verbose "$VerbosePrefix $i`: vsm: config started"
            $KeepGoing = $true
            continue
        }

        if ($KeepGoing) {
            # create mlag peer "<peer>"
            $EvalParams.Regex = [regex] '^create\ mlag\ peer\ "(?<peer>.+?)"'
            $Eval = Get-RegexMatch @EvalParams -ReturnGroupNumber 1
            if ($Eval) {
                $New = [MlagPeer]::new()
                $New.Name = $Eval

                $ReturnObject.Peer += $New
                continue
            }

            # configure mlag peer "<peer>" ipaddress <ip> vr <vr>
            $EvalParams.Regex = [regex] '^configure\ mlag\ peer\ "(?<peer>.+?)"(?<alt>\ alternate)?\ ipaddress\ (?<ip>.+?)\ vr\ (?<vr>[^\ ]+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $PeerName = $Eval.Groups['peer'].Value
                $New = [MlagPeerAddress]::new()
                $New.IpAddress = $Eval.Groups['ip'].Value
                $New.VirtualRouter = $Eval.Groups['vr'].Value

                if ($Eval.Groups['alt'].Success) {
                    $New.IsAlternate = $true
                }

                $PeerLookup = $ReturnObject.Peer | Where-Object { $_.Name -eq $PeerName }
                $PeerLookup.PeerAddress += $New
                continue
            }

            # configure mlag peer "<peer>" authentication <auth>
            $EvalParams.Regex = [regex] '^configure\ mlag\ peer\ "(?<peer>.+?)"\ authentication\ (?<auth>[^\ ]+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $PeerName = $Eval.Groups['peer'].Value
                $PeerLookup = $ReturnObject.Peer | Where-Object { $_.Name -eq $PeerName }

                $PeerLookup.AuthenticationType += $Eval.Groups['auth'].Value
                continue
            }

            # enable mlag port <port> peer "<peer>" id <id>
            $EvalParams.Regex = [regex] '^enable\ mlag\ port\ (?<port>.+?)\ peer\ "(?<peer>.+?)"\ id\ (?<id>\d+)'
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                $New = [MlagPort]::new()

                $New.Port = $Eval.Groups['port'].Value
                $New.Peer = $Eval.Groups['peer'].Value
                $New.Id = $Eval.Groups['id'].Value

                $ReturnObject.Port += $New
                continue
            }

            # ignored lines
            foreach ($Rx in $IgnoreRx) {
                $EvalParams.Regex = [regex] $Rx
                $Eval = Get-RegexMatch @EvalParams
                if ($Eval) {
                    continue fileloop
                }
            }

            # lines not processed
            Write-Verbose "$VerbosePrefix $i`: $entry"

            # next config section
            $EvalParams.Regex = [regex] "^(#)\ "
            $Eval = Get-RegexMatch @EvalParams
            if ($Eval) {
                break fileloop
            }
        }
    }
    return $ReturnObject
}