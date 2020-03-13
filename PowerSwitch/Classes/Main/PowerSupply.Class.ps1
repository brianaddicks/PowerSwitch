Class PowerSupply {
    [string]$Model
    [string]$Description
    [int]$StackMember
    [int]$PsuNumber
    [string]$SerialNumber
    [bool]$IsPowered
    [string]$PowerType
    [int]$AcVoltage
    [int]$DcVoltage
    [int]$CurrentWattage
    [int]$MaxWattage

    ##################################### Initiators #####################################
    # Initiator
    PowerSupply() {
    }
}