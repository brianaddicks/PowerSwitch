function Get-RegexMatch {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'RxString')]
        [String]$RegexString,

        [Parameter(Mandatory = $True, Position = 0, ParameterSetName = 'Rx')]
        [regex]$Regex,

        [Parameter(Mandatory = $True, Position = 1)]
        [string]$StringToEval,

        [Parameter(Mandatory = $False)]
        [string]$ReturnGroupName,

        [Parameter(Mandatory = $False)]
        [int]$ReturnGroupNumber,

        [Parameter(Mandatory = $False)]
        $VariableToUpdate,

        [Parameter(Mandatory = $False)]
        [string]$ObjectProperty,

        [Parameter(Mandatory = $False)]
        [string]$LoopName,

        [Parameter(Mandatory = $False)]
        [string]$LineNumber
    )

    $VerbosePrefix = "Get-RegexMatch: "

    if ($RegexString) {
        $Regex = [Regex] $RegexString
    }

    if ($ReturnGroupName) { $ReturnGroup = $ReturnGroupName }
    if ($ReturnGroupNumber) { $ReturnGroup = $ReturnGroupNumber }

    if ($LineNumber) {
        <# function WriteGlobalVariableLog ($LineNumber, $Contents, $Match) {
            $NewLogEntry = "" | Select-Object -Property LineNumber, Contents, Match
            $NewLogEntry.LineNumber = $LineNumber
            $NewLogEntry.Contents = $Contents
            $NewLogEntry.Match = $Match

            if ($null -eq $Global:PowerSwitchMatch) {
                $Global:PowerSwitchMatch = New-Object 'System.Collections.Generic.List[psobject]'
            }
            $Lookup = $Global:PowerSwitchMatch | Where-Object { $_.LineNumber -eq $LineNumber }
            if ($Lookup) {
                if ($Match) {
                    $Global:PowerSwitchMatch.Add($NewLogEntry)
                }
            } else {
                $Global:PowerSwitchMatch.Add($NewLogEntry)
            }
		} #>

        function WriteGlobalVariableLog ($LineNumber, $Contents) {
            #$NewLogEntry = "" | Select-Object -Property LineNumber, Contents, Match
            #$NewLogEntry.LineNumber = $LineNumber
            #$NewLogEntry.Contents = $Contents
            #$NewLogEntry.Match = $Match

            if ($null -eq $Global:PowerSwitchMatch) {
                $Global:PowerSwitchMatch = @{}
            }

            $Global:PowerSwitchMatch.$LineNumber = $Contents

            <# $Lookup = $Global:PowerSwitchMatch | Where-Object { $_.LineNumber -eq $LineNumber }
            if ($Lookup) {
                if ($Match) {
                    $Global:PowerSwitchMatch.Add($NewLogEntry)
                }
            } else {
                $Global:PowerSwitchMatch.Add($NewLogEntry)
            } #>
        }

    } else {
        function WriteGlobalVariableLog () {}
    }

    $Match = $Regex.Match($StringToEval)
    if ($Match.Success) {
        #Write-Verbose "$VerbosePrefix Matched: $($Match.Value)"
        if ($ReturnGroup) {
            #Write-Verbose "$VerbosePrefix ReturnGroup"
            switch ($ReturnGroup.Gettype().Name) {
                "Int32" {
                    $ReturnValue = $Match.Groups[$ReturnGroup].Value.Trim()
                }
                "String" {
                    $ReturnValue = $Match.Groups["$ReturnGroup"].Value.Trim()
                }
                default { Throw "ReturnGroup type invalid" }
            }
            if ($VariableToUpdate) {
                if ($VariableToUpdate.Value.$ObjectProperty) {
                    #Property already set on Variable
                    WriteGlobalVariableLog $LineNumber $StringToEval
                    continue $LoopName
                } else {
                    WriteGlobalVariableLog $LineNumber $StringToEval
                    $VariableToUpdate.Value.$ObjectProperty = $ReturnValue
                    Write-Verbose "$ObjectProperty`: $ReturnValue"
                }
                continue $LoopName
            } else {
                WriteGlobalVariableLog $LineNumber $StringToEval
                return $ReturnValue
            }
        } else {
            WriteGlobalVariableLog $LineNumber $StringToEval
            return $Match
        }
    } else {
        if ($ObjectToUpdate) {
            #WriteGlobalVariableLog $LineNumber $StringToEval $false
            return
            # No Match
        } else {
            #WriteGlobalVariableLog $LineNumber $StringToEval $false
            return $false
        }
    }
}