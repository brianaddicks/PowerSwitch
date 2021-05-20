function Resolve-ShortPortString {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [string[]]$PortList,

        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateSet("Exos")]
        [string]$SwitchType
    )

    $VerbosePrefix = "Resolve-ShortPortString: "

    $ReturnObject = ""
    switch ($SwitchType) {
        'Exos' {
            foreach ($port in $PortList) {
                # check for correct format
                $Rx = [regex] '(^\d+$|^\d+:\d+$)'
                if (-not $Rx.Match($port).Success) {
                    Throw "$VerbosePrefix PortList contains invalid port name: $port"
                }

                $Split = $port.Split(':')
                if ($Split.Count -gt 1) {
                    $StackNumber = $Split[0]
                    $PortNumber = $Split[1]
                } else {
                    $StackNumber = '0'
                    $PortNumber = $port
                }
                $NextPortNumber = "$([int]$LastPortNumber + 1)"

                if ($StackNumber -ne $LastStackNumber) {
                    if ($ReturnObject -ne '') {
                        $ReturnObject += ','
                    }
                    $ReturnObject += $StackNumber + ':' + $PortNumber
                } else {
                    # not the first port
                    if ($PortNumber -eq $NextPortNumber) {
                        # consecutive port
                        if ($ReturnObject -match '-\d+$') {
                            # already in the middle of a range
                            $ReturnObject = $ReturnObject -replace '-\d+(?=$)',"-$PortNumber"
                        } else {
                            $ReturnObject += "-$PortNumber"
                        }
                    } else {
                        $ReturnObject += ',' + $StackNumber + ':' + $PortNumber
                    }
                }


                $LastPortNumber = $PortNumber
                $LastStackNumber = $StackNumber

                Write-Verbose "$port - $ReturnObject"
            }
            continue
        }
    }

    $ReturnObject -replace '0:',''
}