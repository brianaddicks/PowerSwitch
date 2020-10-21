Class Vlan {
    [string]$Name
    [int]$Id
    [string[]]$UntaggedPorts
    [string[]]$TaggedPorts
    [bool]$Enabled = $true

    # Exos
    [string]$Description

    ##################################### Initiators #####################################
    # Initiator
    Vlan([int]$VlanId) {
        $this.Id = $VlanId
    }

    Vlan([string]$VlanName) {
        $this.Name = $VlanName
    }

    #region methods
    ########################################################

    # ToExos
    [string[]] ToExos() {
        $ReturnObject = @()

        # exos vlans have to have a name, adding a generic one if none specified
        if (-not $this.Name) {
            $VlanName = 'Vlan' + $This.id
        } else {
            $VlanName = $this.Name
        }

        # vlan 1 is exempt from tag/creation commands
        if ($this.Id -ne 1) {
            $ReturnObject += 'create vlan "' + $VlanName + '"'
            $ReturnObject += 'configure vlan "' + $VlanName + '" tag ' + $this.Id
        } else {
            # forcing name for default vlan
            $VlanName = 'default'
        }

        # description
        if ($this.Description) {
            $ReturnObject += 'configure vlan "' + $VlanName + '" description "' + $this.Description + '"'
        }

        # tagged ports
        if ($this.TaggedPorts.Count -gt 0) {
            $ResolvedPortString = Resolve-ShortPortString -PortList $this.TaggedPorts -SwitchType Exos
            $ReturnObject += 'configure vlan "' + $VlanName + '" add ports ' + $ResolvedPortString + ' tagged'
        }

        # tagged ports
        if ($this.UntaggedPorts.Count -gt 0) {
            $ResolvedPortString = Resolve-ShortPortString -PortList $this.UntaggedPorts -SwitchType Exos
            $ReturnObject += 'configure vlan "' + $VlanName + '" add ports ' + $ResolvedPortString + ' untagged'
        }

        return $ReturnObject
        <# [xml]$Doc = New-Object System.Xml.XmlDocument
        $root = $Doc.CreateNode("element","address",$null)

        # Start Entry Node
        $EntryNode = $Doc.CreateNode("element","entry",$null)
        $EntryNode.SetAttribute("name",$this.Name)

        # Start Type Node with Value
        $TypeNode = $Doc.CreateNode("element",$this.Type,$null)
        $TypeNode.InnerText = $this.Value
        $EntryNode.AppendChild($TypeNode)

        if ($this.Tags) {
            # Tag Members
            $MembersNode = $Doc.CreateNode("element",'tag',$null)
            foreach ($member in $this.Tags) {
                $MemberNode = $Doc.CreateNode("element",'member',$null)
                $MemberNode.InnerText = $member
                $MembersNode.AppendChild($MemberNode)
            }
            $EntryNode.AppendChild($MembersNode)
        }

        if ($this.Description) {
            # Description
            $DescriptionNode = $Doc.CreateNode("element","description",$null)
            $DescriptionNode.InnerText = $this.Description
            $EntryNode.AppendChild($DescriptionNode)
        }

        # Append Entry to Root and Root to Doc
        $root.AppendChild($EntryNode)
        $Doc.AppendChild($root)

        return $Doc #>
    }

    ########################################################
    #endregion methods
}
