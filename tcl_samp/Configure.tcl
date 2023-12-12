##################################################################################
#
# $Header: //ral_depot/products/IxChariot6.70.27/HwPairAPI/TCL/Configure.tcl#1 $
# $DateTime: 2008/06/17 13:37:46 $
# $Author: aameling $
#
# $Workfile: Configure.tcl $
#
#   Copyright © 2003-2006 by IXIA
#   All Rights Reserved.
#
# Authors:
#   Debby Stopp and Derek Foster.
#
# Description:
#   The file contains all the procs required to configure the next set of streams 
#   as defined by the specified stream definition file <sdfFile>, as well as 
#   write/commit the configuration to Ixia hardware <ixServer>.  
#
###################################################################################
#
#   PUBLIC INTERFACE:
#
#       CheckLinkState          check the link state of all ports.
#       ConfigEndpoint          configure an endpoint.
#       ConfigPair              configure a hardware performance pair.
#       ConfigPort              configure a hardware port.
#       DeleteAllStreams        delete all streams on port.
#       TakeOwnership           take ownership of this port.
#       VerifyPort              verify that port supports required features.
#       WritePortConfig         commit Ixia port configuration to hardware.
#
#   PRIVATE INTERFACE:
#
#       configAddresses         Configures the IP/MAC/VLAN addresses for the stream.
#       configPacketGroup       Configures packet group.
#       configStreamFrameSize   Configures the frame size for the stream.
#       configStreamMetrics     Configures the stream for metrics collection.
#       configStreamUdfs        Configures the User-Definable Fields for the stream.
#       configTxRxModes         Configures transmit and receive modes of port.
#       configVlan              Configures the VLAN address.
#       countStreams            Returns streamId of last enabled stream on port.
#       getPairInfo             Initializes the Pair definition array.
#       loadStreamFile          Load stream configuration file.
#       programFilters          Configures the receive port pattern filters.
#
###################################################################################

package require IxTclServices


########################################################################################
#
# Procedure:   ixChariot::VerifyPort
#
# Description: Verifies that this port supports the required feature set for ixChariot
#              h/w streams feature.  Specifically, the port needs to be a tpm/dpm, non-ALM
#
# Argument(s): hwPort   - in the form {chassis card port}
#
# Returns:
#    NO_ERROR                   : if no error
#    PORT_NOT_AVAILABLE         : if port is not available
#    PORT_NO_FEATURE            : if port feature set not supported on port
#    INTERNAL_ERROR             : if invalid hwport specified
#
########################################################################################
proc ixChariot::VerifyPort {hwPort} \
{

    #LogEvent "Verifying [list $hwPort]"

    if {[scan [join $hwPort] "%d %d %d" chassisId cardId portId] != 3} {
        ReturnStatus INTERNAL_ERROR "Invalid hwPort specified: \"[join $hwPort]\"."
    }

    if {![port canUse $chassisId $cardId $portId]} {
        # Port %1 is not available, check ownership.
        ReturnStatus PORT_NOT_AVAILABLE [join $hwPort "."]
    }

    if {[port isValidFeature $chassisId $cardId $portId portFeatureLayer7Only] || 
       ![port isValidFeature $chassisId $cardId $portId portFeatureAdvancedScheduler]} \
    {
        # Required feature set is not supported on port %1.
        ReturnStatus PORT_NO_FEATURE [join $hwPort "."]
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::VerifyPort


########################################################################################
#
# Procedure:   ixChariot::TakeOwnership
#
# Description: Takes ownership of this port.  This shouldn't be 
#              done on every config, just at the beginning of a test.
#
# Argument(s): hwPort   - in the form {chassis card port}
#
# Returns:
#    NO_ERROR                   : if no error
#    TAKE_OWNERSHIP_FAILED      : if error taking ownership of port
#    INTERNAL_ERROR             : if invalid hwport specified
#
########################################################################################
proc ixChariot::TakeOwnership {hwPort} \
{

    #LogEvent "Taking ownership [list $hwPort]"

    if {[scan [join $hwPort] "%d %d %d" chassisId cardId portId] != 3} {
        ReturnStatus INTERNAL_ERROR "Invalid hwPort specified: \"[join $hwPort]\"."
    }

    if { [ixPortTakeOwnership $chassisId $cardId $portId] } {
        # Error taking ownership of port %1.
        ReturnStatus TAKE_OWNERSHIP_FAILED [join $hwPort "."]
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::TakeOwnership


########################################################################################
#
# Procedure:   ixChariot::DeleteAllStreams
#
# Description: Deletes all the streams on the specified port.  This shouldn't be 
#              done on every config, just at the beginning of a test.
#
# Argument(s): hwPort   - in the form {chassis card port}
#
# Returns:
#    NO_ERROR                   : if no error
#    STREAM_DELETE_FAILED       : if error deleting streams from port
#    INTERNAL_ERROR             : if invalid hwport specified
#
########################################################################################
proc ixChariot::DeleteAllStreams {hwPort} \
{

    LogEvent "Deleting streams [list $hwPort]"

    if {[scan [join $hwPort] "%d %d %d" chassisId cardId portId] != 3} {
        ReturnStatus INTERNAL_ERROR "Invalid hwPort specified: \"[join $hwPort]\"."
    }

    if [port reset $chassisId $cardId $portId] {
        # Error deleting streams from port %1.
        ReturnStatus STREAM_DELETE_FAILED [join $hwPort "."]
    }

    # The following piece of black magic keeps us from hosing Chariot
    # multicast streams under IxOs 3.80. [39038]
    set pl [list $chassisId,$cardId,$portId]
    if {[ixWriteConfigToHardware pl -noProtocolServer] != $::TCL_OK} {
        # Error writing configuration to hardware
        ReturnStatus WRITE_PORT_CONFIG_FAILED [join $hwPort "."]
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::DeleteAllStreams


########################################################################################
#
# Procedure:    ixChariot::ConfigPort
#
# Description:  Selects an Ixia hardware port to be used by one or more hardware
#               performance pairs, and specifies the configuration of that port.
#
# Argument(s):  hwPort      - port address in the form {chassis card port}.
#               portType    - hardware performance pair port type.
#                             ipV4Only (1): port may receive IPv4 packets only.
#                             ipV6Compatible (2): may receive both IPv4 and IPv6 packets.
#
# Returns:
#    NO_ERROR                   : if no error
#    INTERNAL_ERROR             : if invalid hwport specified
#
########################################################################################
proc ixChariot::ConfigPort {hwPort portType} \
{
    variable PortInfo

    LogEvent "Configuring port [list $hwPort] $portType"

    if {[scan [join $hwPort] "%d %d %d" chassisId cardId portId] != 3} {
        ReturnStatus INTERNAL_ERROR "Invalid hwPort specified: \"[join $hwPort]\"."
    }

    if {[info exists PortInfo($hwPort,portType)]} {
        ReturnStatus INTERNAL_ERROR "Port $hwPort multiply defined"
    }

    # Get IPV4 or IPV6 packet group offset.
    if {$portType == $ixChariot::ipV4Only} {
        set groupBase $ixChariot::IPV4_GROUP_OFFSET
    } \
    else {
        set groupBase $ixChariot::IPV6_GROUP_OFFSET
    }

    # Add the specified Ixia port to the table of configured ports.
    set PortInfo($hwPort,portType)      $portType
    set PortInfo($hwPort,groupBase)     $groupBase
    set PortInfo($hwPort,pgOffset)      $groupBase
    set PortInfo($hwPort,vlanSize)      0
    set PortInfo($hwPort,lastStream)    0
    set PortInfo($hwPort,lastRate)      0

    # Prepare the port for use.
    TakeOwnership $hwPort
    VerifyPort $hwPort
    DeleteAllStreams $hwPort
    configTxRxModes $hwPort

    ReturnStatus NO_ERROR

} ;# ixChariot::ConfigPort


########################################################################################
#
# Procedure:    ixChariot::ConfigEndpoint
#
# Description:  Specifies the configuration of an endpoint to be used by one or more
#               hardware performance pairs.
#
# Argument(s):  epId        - Endpoint identifier.
#               hwPort      - Chassis/card/port identifier in the form {chassis card port},
#                             or "none" if the endpoint is not associated with an Ixia port.
#               macAddr     - MAC address.
#               ipAddr      - IP address.
#               vlanTags    - VLAN tags list.
#                             vlanTags ::= { { vlanDef } ... }
#                             vlanDef  ::= vid priority [cfi [tpid]]
#
# Returns:
#    NO_ERROR                   : if no error
#    INTERNAL_ERROR             : if invalid hwport specified
#
########################################################################################
proc ixChariot::ConfigEndpoint {epId hwPort macAddr ipAddr vlanTags} \
{
    variable EndpointInfo
    variable PortInfo

    if {[llength $macAddr] > 1} {
        set macAddr [join $macAddr ":"]
    }

    LogEvent "Configuring endpoint $epId [list $hwPort] $macAddr $ipAddr [list $vlanTags]"

    if {$hwPort != "none"} \
    {
        if {[scan [join $hwPort] "%d %d %d" chassisId cardId portId] != 3} {
            ReturnStatus INTERNAL_ERROR "Invalid hwPort specified: \"[join $hwPort]\"."
        }

        if {![info exists PortInfo($hwPort,portType)]} {
            ReturnStatus INTERNAL_ERROR "Port [list $hwPort] not previously configured."
        }

        # Get IPv4 or IPv6 packet group base offset.
        if {[string first ":" $ipAddr] == -1} {
            set groupBase $ixChariot::IPV4_GROUP_OFFSET
        } \
        else {
            set groupBase $ixChariot::IPV6_GROUP_OFFSET
        }

        if {$groupBase > $PortInfo($hwPort,groupBase)} {
            # Store largest base offset used with this port.
            set PortInfo($hwPort,groupBase) $groupBase

            # Update packet group offset.
            set PortInfo($hwPort,pgOffset) [expr {$groupBase + $PortInfo($hwPort,vlanSize)}]
        }

        # Compute the number of bytes the VLAN tags will add to the frame.
        set vlanSize [expr {[llength $vlanTags] * 4}]

        if {$vlanSize > $PortInfo($hwPort,vlanSize)} {
            # Store largest VLAN size used with this port.
            set PortInfo($hwPort,vlanSize) $vlanSize

            # Update packet group offset.
            set PortInfo($hwPort,pgOffset) [expr {$PortInfo($hwPort,groupBase) + $vlanSize}]
        }
    }

    # Save endpoint configuration.
    set EndpointInfo($epId,hwPort)      $hwPort
    set EndpointInfo($epId,macAddr)     $macAddr
    set EndpointInfo($epId,ipAddr)      $ipAddr
    set EndpointInfo($epId,vlanTags)    $vlanTags

    ReturnStatus NO_ERROR

} ;# ixChariot::ConfigEndpoint


########################################################################################
#
# Procedure:    ixChariot::ConfigPair
#
# Description:  Configures a hardware performance pair.
#
# Argument(s):  epId1           - Endpoint identifier 1.
#               epId2           - Endpoint identifier 2.
#               sdfFile         - Stream definition file (.str or .sdf).
#               streamType      - defaultStream (0): standard stream.
#                                 voipStream (1) : voice over IP stream,
#                                 voipAsd (2) : voice over IP stream defined in an ASD.
#               pgIdList        - Packet group identifier list.
#               percentMaxRate  - Percent of max rate to config streams, or "same".
#               frameRate       - Transmission rate, in packets per second.
#                                 Only used for VoIP streams.
#               measureStats    - statsDisable (0) to enable neither filters nor metrics.
#                                 statsEnable  (1) to enable both filters and metrics.
#                                 statsFilter  (2) to enable filters but not metrics.
#
# Returns:
#   INTERNAL_ERROR              : invalid hardware port specified
#   INTERNAL_ERROR              : invalid percentMaxRate specified
#   NO_ERROR                    : if no error
#   PACKET_GROUP_SET_RX_FAILED  : error setting receive packet group
#   PACKET_GROUP_SET_TX_FAILED  : error setting transmit packet group
#   STREAM_GET_FAILED           : error getting stream configuration
#   STREAM_SET_FAILED           : error setting stream configuration
#
########################################################################################
proc ixChariot::ConfigPair {epId1 epId2 sdfFile streamType pgIdList percentMaxRate \
    {frameRate 0} {measureStats 1} } \
{
    variable Pair   ;# for debugging
    variable txPortList
    variable rxPortList
    variable filterPortList

    set retCode $::TCL_OK

    LogEvent "Configuring pair $epId1 $epId2 \"$sdfFile\" $streamType [list $pgIdList] $percentMaxRate $frameRate $measureStats"

    # Get pair information.
    getPairInfo Pair $epId1 $epId2 $pgIdList

    # Ignore percentMaxRate for VoIP streams.
    if { $streamType == $ixChariot::voipStream || 
         $streamType == $ixChariot::voipAsd } \
    {
        set percentMaxRate "same"
    }

    # Make sure percentMaxRate is valid.
    if { $percentMaxRate != "same" } \
    {
        if {$percentMaxRate <= 0 || $percentMaxRate > 100} {
            ReturnStatus INTERNAL_ERROR "Invalid percentMaxRate specified ($percentMaxRate)"
        }
        set percentMaxRate [expr double($percentMaxRate)]
        # Cumulative addition errors may cause us to over-subscribe the line, so we 
        # limit the percentMaxRate used internally to < 100%.
        if {[expr {$percentMaxRate > 99.99}]} {
            set percentMaxRate 99.99
        }
    } ;# if

    # Load the stream configuration file.
    loadStreamFile Pair $sdfFile

    # Reset packet group object.
    packetGroup setDefault

    #
    # Repeat the following for each side of the configuration.
    #
    foreach side {1 2} {

        # If the source and destination ports are the same, don't configure the
        # streams a second time.
        if {$Pair(1,hwPort) == $Pair(2,hwPort) && $side == 2} {
            continue
        }

        # If the endpoint is not an Ixia port, we have no further work to do.
        set hwPort $Pair($side,hwPort)
        if {$hwPort == "none"} {
            continue
        }

        # Get source port address.
        scan $hwPort "%d %d %d" chassisId cardId portId
        set msgItem $Pair($side,msgItem)

        set totalStreams  [countStreams totalRateUsed $chassisId $cardId $portId]
        set newStreams    [expr $totalStreams - $Pair($side,lastStreamId)]
        set newRateUsed   [expr {$totalRateUsed - $Pair($side,lastRateUsed)}]

        if {$side==1 && $totalStreams==0} {
            ReturnStatus NO_STREAMS_DEFINED
        }

        if {$newStreams > 0} {

            # Get destination port address.
            set destSide $Pair($side,destSide)
            set destPort $Pair($destSide,hwPort)

            if {$destPort != "none"} {
                scan $destPort "%d %d %d" destChassisId destCardId destPortId

                    # Add destination to the list of ports for which we will need
                    # to configure the packet-reject filter.
                    if { [lsearch $filterPortList $destPort] == -1 } {
                        lappend filterPortList $destPort
                    }

                    set txPgOffset $Pair($side,pgOffset)
                    set rxPgOffset $Pair($destSide,pgOffset)
            } \
            else {
                # The destination is not a port. Force an error if we get sloppy.
                catch {unset destChassisId}
                catch {unset destCardId}
                catch {unset destPortId}
                catch {unset txPgOffset}
                catch {unset rxPgOffset}
            }

            #
            # Repeat the following for each stream in the configuration.
            #
            for {set streamId [expr $Pair($side,lastStreamId) + 1]} \
                {$streamId <= $totalStreams} \
                {incr streamId} \
            {

                # Get the configuration for this stream.
                if [stream get $chassisId $cardId $portId $streamId] {
                    # Error getting stream: port %1 stream %2.
                    ReturnStatus STREAM_GET_FAILED $msgItem $streamId
                }

                # Skip this stream if it's not enabled.
                if { ![stream cget -enable] } {
                    continue
                }

                # Configure IP and MAC addresses for this stream.
                configAddresses Pair $side $streamId

                if {$destPort != "none"} \
                {
                    # Determine stream name.
                    set streamName "[file tail $sdfFile], PGID $Pair($side,pgId)"
                    if {[stream cget -name] != ""} {
                        set streamName "[stream cget -name] - $streamName"
                    }
                    stream config -name [string range $streamName 0 59]
                }

                # Determine transmit rate for this stream.
                if { $percentMaxRate == "same" } \
                {
                    # Don't adjust the stream rate.
                    set perStreamRate "same"
                } \
                elseif { [expr {$newRateUsed == 0}] } {
                    # Distribute bandwidth equally over all streams.
                    set perStreamRate [expr {$percentMaxRate / $newStreams}]
                } \
                else {
                    # Distribute bandwidth proportionally over all streams.
                    set perStreamRate [expr { 
                        ([stream cget -percentPacketRate] / $newRateUsed) * $percentMaxRate
                    }]
                }
                stream config -dma contPacket
                if {$perStreamRate != "same"} {
                    stream config -rateMode usePercentRate
                    stream config -percentPacketRate $perStreamRate
                }

                # Configure stream so we can collect metrics.
                if {$measureStats && $destPort != "none"} {
                    if {$measureStats == $ixChariot::statsEnable} {
                        configStreamMetrics
                    }
                    configStreamFrameSize $msgItem $streamId $txPgOffset
                }

                # If this is a voice-over-IP stream, set the transmission rate according to
                # the frame rate (in packets per second) supplied by the caller. We do this
                # after calling configStreamMetrics because the latter may adjust the frame size.
                if { $streamType == $ixChariot::voipStream } {
                    set frameSize [stream cget -framesize]
                    set rate [calculatePercentMaxRate $chassisId $cardId $portId $frameRate $frameSize]
                    stream config -rateMode usePercentRate
                    stream config -percentPacketRate $rate
                }

                if {$measureStats && $destPort != "none"} \
                {
                    # The pattern type must be Fixed for us to collect metrics for a VoIP stream.
                    if { $streamType != $ixChariot::defaultStream } {
                        if { [stream cget -patternType] != $::nonRepeat } {
                            # Pattern type not Fixed for VoIP stream.
                            ReturnStatus PATTERN_TYPE_NOT_FIXED $msgItem $streamId
                        }
                    }

                    # Configure UDFs for stream.
                    configStreamUdfs $msgItem $streamId $streamType $txPgOffset
                }

                #LogEvent "Setting port [list $hwPort] stream $streamId"
                if [stream set $chassisId $cardId $portId $streamId] {
                    # Error setting stream configuration: port %1 stream %2.
                    ReturnStatus STREAM_SET_FAILED $msgItem $streamId
                }

                if [stream write $chassisId $cardId $portId $streamId] {
                    # Error writing stream configuration: port %1 stream %2.
                    ReturnStatus STREAM_WRITE_FAILED $msgItem $streamId
                }

                if {$measureStats && $destPort != "none"} \
                {
                    # Configure packet group that lives in streams, using the destination CCP 
                    # as the signature. I'm going to set it here so I can snoop the offset of
                    # the signature from the already config'd stream.
                    configPacketGroup \
                        $destChassisId $destCardId $destPortId \
                        $txPgOffset \
                        $Pair($side,pgId)

                    if [packetGroup setTx $chassisId $cardId $portId $streamId] {
                        # Error setting transmit packet group: port %1 stream %2.
                        ReturnStatus PACKET_GROUP_SET_TX_FAILED $msgItem $streamId
                    }
                }

            } ;# for
            
            # add tx/rx ports here, but only if they weren't already in the list...
            if {[lsearch $txPortList $hwPort] < 0} {
                lappend txPortList $hwPort
            }

            if {$measureStats && $destPort != "none"} {
                if {[lsearch $rxPortList $destPort] < 0} {
                    # Configure pg that lives on the rx port, using the destination CCP 
                    # as the signature.
                    configPacketGroup $destChassisId $destCardId $destPortId $rxPgOffset

                    if [packetGroup setRx $destChassisId $destCardId $destPortId] {
                        # Error setting receive packet group: port %3.
                        ReturnStatus PACKET_GROUP_SET_RX_FAILED $msgItem $streamId [join $destPort "."]
                    }
                    lappend rxPortList $destPort
                }
            }

        } ;# if
        
    } ;# foreach

    ReturnStatus NO_ERROR

} ;# ixChariot::ConfigPair

    
########################################################################################
#
# Procedure:   ixChariot::WritePortConfig
#
# Description: Commit the Ixia port configuration to ixServer.
#
# Argument(s): hwPort   - in the form {chassis card port}
#
# Returns:
#    NO_ERROR                   : if no error
#    INTERNAL_ERROR             : if invalid port specified
#    WRITE_PORT_CONFIG_FAILED   : if write configuration failed
#
########################################################################################
proc ixChariot::WritePortConfig {hwPort} \
{
    variable filterPortList
    variable firstWriteConfig

    if {$firstWriteConfig} {

        variable txPortList
        variable rxPortList

        set txPortList [lsort $txPortList]
        set rxPortList [lsort $rxPortList]
        set firstWriteConfig 0

        # Issue ARP requests for all ports.
        #IssueArpRequest 4000
    }

    LogEvent "Writing configuration for port [list $hwPort]"

    if {[scan [join $hwPort] "%d %d %d" chassisId cardId portId] != 3} {
        ReturnStatus INTERNAL_ERROR "Invalid hwPort specified: \"[join $hwPort]\"."
    }

    # The following piece of black magic keeps us from hosing Chariot
    # multicast streams under IxOs 3.80. [39038]
    set pl [list $chassisId,$cardId,$portId]
    if {[ixWriteConfigToHardware pl -noProtocolServer] != $::TCL_OK} {
        # Error writing configuration to hardware
        ReturnStatus WRITE_PORT_CONFIG_FAILED [join $hwPort "."]
    }

    # Set the pattern filter if this is a receive port.
    if {[lsearch $filterPortList $hwPort] != -1} {
        programFilters [list $hwPort]
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::WritePortConfig


########################################################################################
#
# Procedure:   ixChariot::CheckLinkState
#
# Description: Check the link state of all the ports
#
# Argument(s): None.
#
# Returns:
#    NO_ERROR                   : if no error
#    INTERNAL_ERROR             : if no ports defined
#    LINK_DOWN                  : if link is down
#
########################################################################################
proc ixChariot::CheckLinkState {} \
{
    variable txPortList
    variable rxPortList

    LogEvent "Checking link state"

    set allPorts [lsort -unique [concat $txPortList $rxPortList]]

    if {[llength $allPorts] == 0} {
        ReturnStatus INTERNAL_ERROR "No ports defined"
    }

    if [expr {[ixCheckLinkState allPorts] != $::TCL_OK}] {
        # Link is down.
        ReturnStatus LINK_DOWN
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::CheckLinkState


########################################################################################
#                   local use procs only
########################################################################################


########################################################################################
#
# Procedure:    ixChariot::configAddresses
#
# Description:  Configures the IP/MAC/VLAN addresses of the current stream.
#
# Argument(s):  pair - name of pair definition array.
#                   *,destSide - destination side number.
#                   *,hwPort - chassis/card/port address.
#                   *,ipAddr - IP address.
#                   *,macAddr - MAC address.
#               side - side number (1 or 2).
#               streamId - stream identifier.
#
# Returns:
#   NO_ERROR                    : if no error
#   INVALID_STREAM_TYPE         : protocol type for stream is neither IPv4 nor IPv6
#   IPV4_GET_FAILED             : error getting IPv4 configuration
#   IPV4_SET_FAILED             : error setting IPv4 configuration
#   IPV6_GET_FAILED             : error getting IPv6 configuration
#   IPV6_SET_FAILED             : error setting IPv6 configuration
#   IPV6_ADDRESS_IPV4_STREAM    : IPv6 address specified for IPv4 stream.
#   IPV6_STREAM_IPV4_ENDPOINT   : IPv6 stream specified for IPv4 endpoint.
#
########################################################################################
proc ixChariot::configAddresses {pair side streamId} \
{
    upvar $pair Pair

    variable ixOsVersion

    # Get source port address.
    set hwPort $Pair($side,hwPort)
    scan $hwPort "%d %d %d" chassisId cardId portId
    set msgItem $Pair($side,msgItem)

    set destSide $Pair($side,destSide)

    # Configure MAC addresses.
    stream config -sa                $Pair($side,macAddr)
    stream config -saRepeatCounter   idle
    stream config -numSA             1
    stream config -daRepeatCounter   daArp
    # Default to the expected destination MAC address, in case the ARP fails. [32618]
    stream config -da                $Pair($destSide,macAddr)
    stream config -numDA             1

    # Get IP addresses.
    set srcAddr  $Pair($side,ipAddr)
    set destAddr $Pair($destSide,ipAddr)

    #LogEvent "Configuring addresses for port [list $hwPort] stream $streamId"
    #LogEvent "sa $Pair($side,macAddr) da $Pair($destSide,macAddr)"
    #LogEvent "src $srcAddr dest $destAddr"

    if {[protocol cget -name] == $::ipV4} {
        # Make sure addresses are compatible with streams.
        if {[string first ":" $srcAddr] != -1 ||
            [string first ":" $destAddr] != -1} \
        {
            # IPv6 address specified for IPv4 stream: port %1 stream %2.
            ReturnStatus IPV6_ADDRESS_IPV4_STREAM $msgItem $streamId
        }
        if [ip get $chassisId $cardId $portId] {
            # Error getting IPv4 protocol configuration: port %1 stream %2.
            ReturnStatus IPV4_GET_FAILED $msgItem $streamId
        }
        ip config -sourceIpAddr   $srcAddr
        ip config -destIpAddr     $destAddr
        if [ip set $chassisId $cardId $portId] {
            # Error setting IPv4 protocol configuration: port %1 stream %2.
            ReturnStatus IPV4_SET_FAILED $msgItem $streamId
        }
    } elseif {[protocol cget -name] == $::ipV6} {
        # Make sure the stream is compatible with the destination endpoint.
        if {$Pair($destSide,portType) == $ixChariot::ipV4Only} \
        {
            # IPv6 stream specified for IPv4 endpoint: port %1 stream %2.
            ReturnStatus IPV6_STREAM_IPV4_ENDPOINT $msgItem $streamId
        }
        # IPv4 addresses can be represented in IPv6 networks as either ::n.n.n.n 
        # or ::FFFF:n.n.n.n, so this is not necessarily an error.
        if [ipV6 get $chassisId $cardId $portId] {
            # Error getting IPv6 protocol configuration: port %1 stream %2.
            ReturnStatus IPV6_GET_FAILED $msgItem $streamId
        }
        ipV6 config -sourceAddr   $srcAddr
        ipV6 config -destAddr     $destAddr
        if [ipV6 set $chassisId $cardId $portId] {
            # Error setting IPv6 protocol configuration: port %1 stream %2.
            ReturnStatus IPV6_SET_FAILED $msgItem $streamId
        }
    } else {
        # Stream type not IPv4 or IPv6: port %1 stream %2.
        ReturnStatus INVALID_STREAM_TYPE $msgItem $streamId
    }

    # Get VLAN address.
    set vlanTags $Pair($side,vlanTags)

    if {[llength $vlanTags] > 1} {

        # Configure multiple VLAN tags using the stacked VLAN feature.

        if {$ixOsVersion < 4.0} {
            ReturnStatus INTERNAL_ERROR "IxOS $ixOsVersion does not support stacked VLANs."
        }

        protocol config -enable802dot1qTag vlanStacked
        stackedVlan setDefault

        set vlanIndex 0

        foreach vlanDef $vlanTags {

            incr vlanIndex

            configVlan $vlanDef

            if {$vlanIndex <= 2} {
                if {[stackedVlan setVlan $vlanIndex]} {
                    # Error setting vlan configuration: port %1 stream %2.
                    ReturnStatus VLAN_SET_FAILED $msgItem $streamId
                }
            } \
            else {
                if {[stackedVlan addVlan]} {
                    # Error setting vlan configuration: port %1 stream %2.
                    ReturnStatus VLAN_SET_FAILED $msgItem $streamId
                }
            }
        }

        # The TCL guide doesn't tell us we have to do this...
        if [stackedVlan set $chassisId $cardId $portId] {
            # Error setting vlan configuration: port %1 stream %2.
            ReturnStatus VLAN_SET_FAILED $msgItem $streamId
        }
    } \
    elseif {[llength $vlanTags] > 0} {

        # Configure a single VLAN tag.

        if {$ixOsVersion < 4.0} {
            protocol config -enable802dot1qTag true
        } \
        else {
            protocol config -enable802dot1qTag vlanSingle
        }

        configVlan [lindex $vlanTags 0]

        if [vlan set $chassisId $cardId $portId] {
            # Error setting vlan configuration: port %1 stream %2.
            ReturnStatus VLAN_SET_FAILED $msgItem $streamId
        }
    } \
    else {

        if {$ixOsVersion < 4.0} {
            protocol config -enable802dot1qTag false
        } \
        else {
            protocol config -enable802dot1qTag vlanNone
        }

    }

    ReturnStatus NO_ERROR

} ;# ixChariot::configAddresses


########################################################################################
#
# Procedure:   ixChariot::configPacketGroup
#
# Description: Configures the packet group object.
#
# Argument(s): chasID - chassis identifier.
#              cardID - card identifier.
#              portID - port identifier.
#              pgOffset - offset of packet group data in frame.
#              groupId - group identifier.
#
# Returns:     0 : if no error
#              1 : if error
#
########################################################################################
proc ixChariot::configPacketGroup {chasID cardID portID pgOffset {groupId ""} } \
{

    set retCode 0

    packetGroup setDefault

    packetGroup config -signature               [format "db %02d %02d %02d" $chasID $cardID $portID]
    packetGroup config -signatureOffset         [expr {$pgOffset + $ixChariot::PG_SIGNATURE}]
    packetGroup config -groupIdOffset           [expr {$pgOffset + $ixChariot::PG_GROUP_ID}]
    packetGroup config -sequenceNumberOffset    [expr {$pgOffset + $ixChariot::PG_SEQUENCE}]

    if {$groupId != ""} {    
        packetGroup config -allocateUdf             false
        packetGroup config -insertSignature         true
        packetGroup config -insertSequenceSignature true
        packetGroup config -groupId                 $groupId
    }

    return $retCode 

} ;# ixChariot::configPacketGroup


########################################################################################
#
# Procedure:   ixChariot::configStreamFrameSize
#
# Description: Configures the frame size for the current stream.
#
# Argument(s): msgItem - port address for error messages.
#              streamId - stream identifier.
#              pgOffset - packet group offset.
#
# Returns:
#   NO_ERROR                    : if no error.
#   INVALID_FRAMESIZE_TYPE      : if streamSizeType not fixed or random.
#
########################################################################################
proc ixChariot::configStreamFrameSize {msgItem streamId pgOffset} \
{

    # Get minimum frameSize for the stream.
    set minSize [expr {$pgOffset + $ixChariot::FRAME_OVERHEAD}]

    # Get the frameSize type of the stream.
    set sizeType [stream cget -frameSizeType]

    if {$sizeType == $::sizeFixed} {
        # Adjust framesize if it is less than our minimum.
        if {[stream cget -framesize] < $minSize} {
            stream config -framesize $minSize
            LogEvent "Port $msgItem stream $streamId framesize set to $minSize"
        }
    } \
    elseif {$sizeType == $::sizeRandom || $sizeType == $::sizeIncr} {
        # Adjust minimum framesize if it is less than our minimum.
        # If the maximum framesize is also less than our minimum, 
        # convert the stream to fixed size.
        if {[stream cget -frameSizeMIN] < $minSize} {
            if {[stream cget -frameSizeMAX] <= $minSize} {
                stream config -frameSizeType sizeFixed
                stream config -framesize $minSize
                LogEvent "Port $msgItem stream $streamId framesize set to $minSize"
            } \
            else {
                stream config -frameSizeMIN $minSize
                LogEvent "Port $msgItem stream $streamId minFrameSize set to $minSize"
            }
        }
    } \
    else {
        # Reject the stream as unsupported.
        # Stream %1 specifies an unsupported frameSizeType (%2)
        ReturnStatus INVALID_FRAMESIZE_TYPE $streamId $sizeType
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::configStreamFrameSize


########################################################################################
#
# Procedure:   ixChariot::configStreamMetrics
#
# Description: Configures the stream for metrics collection.
#
# Argument(s): None.
#
# Returns:
#   NO_ERROR                    : if no error.
#
########################################################################################
proc ixChariot::configStreamMetrics {} \
{

    if [catch {stream config -enableTimestamp true}] {
        stream config -fir true
    }
    stream config -enableIbg         false
    stream config -enableIsg         false

    ReturnStatus NO_ERROR

} ;# ixChariot::configStreamMetrics


########################################################################################
#
# Procedure:    ixChariot::configStreamUdfs
#
# Description:  Configures the User-Definable Fields for the current stream.
#
# Argument(s):  msgItem - port address for error messages.
#               streamId - stream identifier.
#               streamType - stream type.
#               pgOffset - packet group offset.
#
# Returns:
#   NO_ERROR                    : if no error
#   STREAM_UDF_RESERVED         : stream uses reserved UDF
#   UDF_GET_FAILED              : error getting UDF configuration.
#   UDF_SET_FAILED              : error setting UDF configuration
#
########################################################################################
proc ixChariot::configStreamUdfs {msgItem streamId streamType pgOffset} \
{
    variable kUdf

    # Get configuration of our UDF.
    if {[udf get $kUdf] != $::TCL_OK} {
        # Error getting UDF configuration: port %1 stream %2 UDF %3.
        ReturnStatus UDF_GET_FAILED $msgItem $streamId $kUdf
    }

    # Determine whether our UDF is in use.
    if [udf cget -enable] {
        # Stream uses UDF %3, which is reserved: port %1 stream %2.
        ReturnStatus STREAM_UDF_RESERVED $msgItem $streamId $kUdf
    }

if {0} {
    # Disable UDFs if this is not a VoIP stream.
    if { $streamType != $ixChariot::voipStream && \
         $streamType != $ixChariot::voipAsd } \
    {
        # Compile a list of the UDFs used by the stream file.
        set udfList [list]
        for {set udfNo 1} {$udfNo <= 5} {incr udfNo} {
            if {[udf get $udfNo] == $::TCL_OK} {
                if [udf cget -enable] {
                    lappend udfList $udfNo
                }
            }
        }

        # Log a message if any of them were in use.
        if {[llength $udfList] != 0} {
            LogEvent "Port $msgItem Stream $streamId: Disabling UDF(s) [list $udfList]"
        }

        # Disable all UDFs.
        disableUdfs {1 2 3 4 5}

    } ;# if
}

    # Configure our UDF for sequence number generation.
    udf setDefault
    udf config -enable          true
    udf config -offset          [expr {$pgOffset + $ixChariot::PG_SEQUENCE}]
    udf config -initval         {00 00 00 00}
    udf config -countertype     c32
    udf config -continuousCount true

    # Set configuration of our UDF.
    if [udf set $kUdf] {
        # Error setting UDF configuration: port %1 stream %2 UDF %3.
        ReturnStatus UDF_SET_FAILED $msgItem $streamId $kUdf
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::configStreamUdfs


########################################################################################
#
# Procedure:    ixChariot::configTxRxModes
#
# Description:  Configures the transmit and receive modes of the specified port.
#
# Argument(s):  hwPort - port address in the form {chassis card port}.
#
# Returns:
#   NO_ERROR                    : if no error
#   INTERNAL_ERROR              : if invalid hwport specified
#   CARD_GET_FAILED             : error getting card properties.
#   PORT_GET_FAILED             : error getting port configuration
#   PORT_SET_FAILED             : error setting port configuration
#   PORT_SET_NO_FEATURE         : error setting port - feature not supported
#   PORT_SET_NOT_AVAILABLE      : error setting port - port not available
#
########################################################################################
proc ixChariot::configTxRxModes {hwPort} \
{

    if {[scan [join $hwPort] "%d %d %d" chassisId cardId portId] != 3} {
        ReturnStatus INTERNAL_ERROR "Invalid hwPort specified: \"[join $hwPort]\"."
    }

    # Get item identifier for messages.
    set msgItem [join $hwPort "."]

    # Get the card type.
    if {[card get $chassisId $cardId] != $::TCL_OK} {
        # Error getting card properties: chassis %1 card %2.
        ReturnStatus CARD_GET_FAILED $chassisId $cardId
    }
    set cardType [card cget -type]

    # Get port configuration.
    if [port get $chassisId $cardId $portId] {
        # Error getting port %1.
        ReturnStatus PORT_GET_FAILED $msgItem
    }

    # Put the port into advanced stream mode.
    port config -transmitMode portTxModeAdvancedScheduler

    #
    # According to Debby, wide packet groups are a major performance sink,
    # and we don't want to use them. [30336]
    #
    # Don't enable receive sequence checking ($::portRxSequenceChecking).
    # We don't use it, and it forces the packet filter on a TXS8 into "limited" mode,
    # resulting in all-or-nothing filtering of TCP and UDP packets. [32868]
    #
    # Reenabled wide packet groups so we can get the timestamps, which allow us to
    # do more accurate calculations for VoIP hardware performance pairs. Note that
    # this mode supersedes both the portPacketGroup and the portRxFirstTimeStamp
    # options, which must not be specified at the same time.
    #
    # Don't set wide packet groups for the TXS8. It prevents us from using the filters.
    #
    if {[port isValidFeature $chassisId $cardId $portId portFeatureRxWidePacketGroups] && \
        $cardType != $::card10100Txs8} \
    {
        set rxMode $::portRxModeWidePacketGroup
    } \
    else {
        set rxMode $::portPacketGroup
        LogEvent "Port [list $hwPort] set for regular packet groups"
    }
    #LogEvent [format "Port %s -receiveMode 0x%x" [list $hwPort] $rxMode]
    port config -receiveMode $rxMode

    # Update port configuration.
    switch [port set $chassisId $cardId $portId] {
        $::TCL_ERROR {
            # Error setting configuration of port %1.
            ReturnStatus PORT_SET_FAILED $msgItem
        }
        $::ixTcl_notAvailable {
            # Error setting port %1 - port not available.
            ReturnStatus PORT_SET_NOT_AVAILABLE $msgItem
        }
        $::ixTcl_unsupportedFeature {
            # Error setting port %1 - unsupported feature.
            ReturnStatus PORT_SET_NO_FEATURE $msgItem
        }
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::configTxRxModes


########################################################################################
#
# Procedure:   ixChariot::configVlan
#
# Description: Configures the VLAN address.
#
# Argument(s): vlanDef - VLAN definition.
#
# Returns:     None.
#
########################################################################################
proc ixChariot::configVlan {vlanDef} \
{

    set vlanId  [lindex $vlanDef 0]
    set vlanPri [lindex $vlanDef 1]
    set vlanCfi [lindex $vlanDef 2]
    set vlanTag [lindex $vlanDef 3]

    #LogEvent "vlanId $vlanId vlanPri $vlanPri"

    vlan setDefault

    vlan config -vlanID $vlanId
    vlan config -userPriority $vlanPri

    if {[GetIxOSMajorVersion] >= 4.0} {
        if {$vlanCfi != ""} {
            vlan config -cfi $vlanCfi
        }

        if {$vlanTag != ""} {
            vlan config -protocolTagId $vlanTag
        }
    }

} ;# ixChariot::configVlan


########################################################################################
#
# Procedure:    ixChariot::getPairInfo
#
# Description:  Initializes the Pair definition array.
#
# Argument(s):  pair - name of pair definition array.
#                   *,destSide - destination side number.
#                   *,epId - endpoint identifier.
#                   *,hwPort - chassis/card/port address.
#                   *,ipAddr - IP address.
#                   *,lastRateUsed - 
#                   *,lastStreamId - number of streams defined for port.
#                   *,macAddr - MAC address.
#                   *,msgItem - identifier for error messages.
#                   *,pgId - packet group identifier.
#                   *,pgOffset - offset of packet group signature.
#                   *,portType - HPP port type (ipV4Only, ipV6Compatible).
#                   *,vlanTags - VLAN address list.
#               epId1 - Endpoint identifier 1.
#               epId2 - Endpoint identifier 2.
#               pgIdList - Packet group identifier list.
#
# Returns:
#   NO_ERROR                    : No error.
#   INTERNAL_ERROR              : Endpoint not previously configured.
#
########################################################################################
proc ixChariot::getPairInfo {pair epId1 epId2 pgIdList} \
{
    variable EndpointInfo
    variable PortInfo

    upvar $pair Pair

    foreach {side epId} [list 1 $epId1 2 $epId2] {

        if {![info exists EndpointInfo($epId,hwPort)]} {
            ReturnStatus INTERNAL_ERROR "Endpoint $epId not previously configured."
        }

        set hwPort                  $EndpointInfo($epId,hwPort)

        set Pair($side,epId)        $epId
        set Pair($side,hwPort)      $hwPort
        set Pair($side,ipAddr)      $EndpointInfo($epId,ipAddr)
        set Pair($side,macAddr)     $EndpointInfo($epId,macAddr)
        set Pair($side,vlanTags)    $EndpointInfo($epId,vlanTags)
        set Pair($side,destSide)    [expr {3 - $side}]

        if {$hwPort != "none"} {
            set Pair($side,msgItem)     [join $hwPort "."]
            set Pair($side,portType)    $PortInfo($hwPort,portType)
            set Pair($side,pgId)        [lindex $pgIdList [expr {$side-1}]]
            set Pair($side,pgOffset)    $PortInfo($hwPort,pgOffset)

            # Derive chassis, card, and port identifiers for this endpoint.
            scan $hwPort "%d %d %d" chassisId cardId portId

            # Determine the number of streams already defined for this port.
            set Pair($side,lastStreamId) [countStreams totalRateUsed $chassisId $cardId $portId]
            set Pair($side,lastRateUsed) $totalRateUsed
        } \
        else {
            set Pair($side,msgItem)     $Pair($side,ipAddr)
            set Pair($side,portType)    $ixChariot::ipV6Compatible

            # These fields are undefined if this is not an HPP.
            # We undefine them to cause an error if they are referenced.
            catch {unset Pair($side,pgId)}
            catch {unset Pair($side,pgOffset)}
            catch {unset Pair($side,lastStreamId)}
            catch {unset Pair($side,lastRateUsed)}
        }

    } ;# foreach

    ReturnStatus NO_ERROR

} ;# ixChariot::getPairInfo


########################################################################################
#
# Procedure:    ixChariot::loadStreamFile
#
# Description:  Loads the stream configuration file.
#
# Argument(s):  pair - name of pair definition array.
#                   *,hwPort - chassis/card/port address.
#                   *,lastStreamId - last stream identifier.
#               sdfFile - name of stream configuration file.
#
# Returns:
#   NO_ERROR                    : no error
#   INTERNAL_ERROR              : stream configuration file does not exist.
#   INTERNAL_ERROR              : stream configuration file has unknown extension.
#   SDF_IMPORT_FAILED           : error sourcing SDF file
#   STR_IMPORT_FAILED           : error importing STR file
#
########################################################################################
proc ixChariot::loadStreamFile {pair sdfFile} \
{
    upvar $pair Pair

    # Make sure the stream configuration file exists.
    if {![file exists $sdfFile]} {
        ReturnStatus INTERNAL_ERROR "Stream configuration file \"$sdfFile\" does not exist."
    }

    switch [file extension $sdfFile] {
        ".sdf" {
            if [catch {
                set hwPort $Pair(1,hwPort)
                source $sdfFile
                foreach side {1 2} {
                    set procName "defineEndpoint${side}Streams"
                    set hwPort $Pair($side,hwPort)
                    if {$hwPort != "none"} {
                        scan $hwPort "%d %d %d" chassisId cardId portId
                        sdf::$procName $chassisId $cardId $portId [expr $Pair($side,lastStreamId) + 1]
                    }
                }
            } errorMsg] {
                if {[string match "*VoIP stream exceeds bandwidth*" $errorMsg]} {
                    # VoIP pair exceeds bandwidth of port %1.
                    ReturnStatus VOIP_PAIR_EXCEEDS_BANDWIDTH [join $hwPort "."]
                }
                # Error loading SDF file "%1" on port %2: %3.
                ReturnStatus SDF_IMPORT_FAILED $sdfFile [join $hwPort "."] $errorMsg
            }
        }
        ".str" {
            # right now we only support importing .str files onto E1...
            set hwPort $Pair(1,hwPort)
            scan $hwPort "%d %d %d" chassisId cardId portId
            if [stream import $sdfFile $chassisId $cardId $portId] {
                # Error loading STR file "%1" on port %2: %3.
                ReturnStatus STR_IMPORT_FAILED $sdfFile [join $hwPort "."] $errorMsg
            }
        }
        default {
            ReturnStatus INTERNAL_ERROR "Stream configuration file \"$sdfFile\" has unknown extension."
        }
    } ;# switch

    ReturnStatus NO_ERROR

} ;# ixChariot::loadStreamFile


########################################################################################
#
# Procedure:   ixChariot::programFilters
#
# Description: This procedure programs the pattern filter on each receive port to
#              reject all frames that contain the packet group signature. We do this
#              to keep the port CPU from being overwhelmed by instrumented stream
#              traffic, which is processed entirely by the FPGAs.
#
# Argument(s): portList - list of ports to configure.
#
# Returns:
#   NO_ERROR                    : no error.
#   CARD_GET_FAILED             : error getting card properties.
#   PATTERN_FILTER_SET_FAILED   : error setting pattern filter.
#
########################################################################################
proc ixChariot::programFilters {portList} \
{
    variable PortInfo

    foreach hwPort $portList {
        if {[scan [join $hwPort] "%d %d %d" chassisId cardId portId] != 3} {
            ReturnStatus INTERNAL_ERROR "Invalid hwPort specified: \"[join $hwPort]\"."
        }

        # Get the card type.
        if {[card get $chassisId $cardId] != $::TCL_OK} {
            # Error getting card properties: chassis %1 card %2.
            ReturnStatus CARD_GET_FAILED $chassisId $cardId
        }
        set cardType [card cget -type]

        # If this is a TXS8, don't try to set the pattern reject filter. [32868]
        # Pattern filter support for the TXS8 was introduced in IxOS 3.80. [44571]
        if {$cardType == $::card10100Txs8} {
            if { [expr [GetIxOSMajorVersion] < 3.80] } {
                continue
            }
        }

        # Construct the packet group signature.
        set pattern [format "0xdb%02d%02d%02d" $chassisId $cardId $portId]

        set mask    0x00000000                  ;# all bits in pattern are significant
        set offset  $PortInfo($hwPort,pgOffset) ;# offset of pattern in buffer
        set mode    1                           ;# reject frames containing pattern

        set portArray [list $hwPort]
        set rcmd [format "filter --set-pattern=%s/%s@%d:%d" $pattern $mask $offset $mode]

        variable logFile
        if {![catch {open $logFile a} fileId]} {
            puts $fileId "issuePcpuCommand $portArray $rcmd"
            close $fileId
        }

        global errorInfo
        set errorInfo ""

        if {[catch {::ixServices::issuePcpuCommand portArray -noVerbose $rcmd} rval]} {
            if {[string trim $rval] == ""} {
                set rval "Operation failed"
            }
            # Error setting pattern filter for port %1: %2.
            ReturnStatus PATTERN_FILTER_SET_FAILED [join $hwPort "."] $rval
        }
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::programFilters


########################################################################################
#
# Procedure:   ixChariot::countStreams
#
# Description: Returns the streamId of the last enabled stream on a port.
#
# Argument(s): TotalRateUsed [out] - percentage of line rate used.
#              chassisId - chassis identifier.
#              cardId - card identifier.
#              portId - port identifier.
#              queueId - ATM queue identifier (optional, default = 1).
#
# Returns:     Number of last enabled stream on this port.
#
########################################################################################
proc ixChariot::countStreams {TotalRateUsed chassisId cardId portId {queueId 1}} \
{
    set streamId          1
    set lastEnabledStream 0
    set rateUsed          0.0

    if [port isValidFeature $chassisId $cardId $portId portFeatureAtm] {
        while {[stream getQueue $chassisId $cardId $portId $queueId $streamId] == $::TCL_OK} {
            if [stream cget -enable] {
                set lastEnabledStream $streamId
                set rateUsed [expr {[stream cget -percentPacketRate] + $rateUsed}]
            }
            incr streamId
        }
    } else {
        while {[stream get $chassisId $cardId $portId $streamId] == $::TCL_OK} {
            if [stream cget -enable] {
                set lastEnabledStream $streamId
                set rateUsed [expr {[stream cget -percentPacketRate] + $rateUsed}]
            }
            incr streamId
        }
    }

    if { $TotalRateUsed != "" } {
        upvar $TotalRateUsed totalRateUsed
        set totalRateUsed $rateUsed
    }

    return $lastEnabledStream

} ;# ixChariot::countStreams
