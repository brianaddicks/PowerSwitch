Class MlagPeerAddress {
    [string]$IpAddress
    [string]$VirtualRouter
    [bool]$IsAlternate = $false

    ##################################### Initiators #####################################
    # Initiator
    MlagPeerAddress() {
    }
}

Class MlagPeer {
    [string]$Name
    [MlagPeerAddress[]]$PeerAddress
    [string]$AuthenticationType

    ##################################### Initiators #####################################
    # Initiator
    MlagPeer() {
    }
}

Class MlagPort {
    [string]$Port
    [string]$Peer
    [int]$Id

    ##################################### Initiators #####################################
    # Initiator
    MlagPort() {
    }
}

Class MlagConfig {
    [MlagPeer[]]$Peer
    [MlagPort[]]$Port

    ##################################### Initiators #####################################
    # Initiator
    MlagConfig() {
    }
}