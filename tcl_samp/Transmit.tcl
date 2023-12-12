##################################################################################
# $Header: //ral_depot/products/IxChariot6.70.27/HwPairAPI/TCL/Transmit.tcl#2 $
# $DateTime: 2008/06/30 08:55:55 $
# $Author: mconstantinescu $
#
# $Workfile: Transmit.tcl $
#
#   Copyright © 2003-2007 by IXIA
#   All Rights Reserved.
#
#   Revision Log:
#   09-26-2003  DS  Genesis
#
# Authors:
#   Debby Stopp and Derek Foster.
#
# Description:
#   This file contains all the procs that pertain to starting & stopping 
#   transmit of streams on ixHWPairs.  The current assumption is that 
#   all ports configured with streams will start transmitting at the same 
#   time and all ports will stop transmitting at the same time.  
#
###################################################################################
#
#   PUBLIC INTERFACE:
#
#       CheckTransmitStarted    check whether ports have started transmitting.
#       CheckTransmitStopped    check whether ports have stopped transmitting.
#       IssueArpRequest         issue ARP request on all transmit ports.
#       StartTransmit           start transmit on all hardware ports.
#       StopTransmit            stop transmit on all hardware ports.
#
###################################################################################


########################################################################################
#
# Procedure:   ixChariot::CheckTransmitStarted
#
# Description: Check hardware ports to see whether transmit has started.
#
# Argument(s): None.
#
# Returns:
#   NO_ERROR                    : if no error
#   INTERNAL_ERROR              : if no transmit ports defined
#   TRANSMIT_NOT_STARTED        : if port not transmitting
#   START_TRANSMIT_FAILED       : if error starting transmit
#
########################################################################################

proc ixChariot::CheckTransmitStarted {} \
{
    variable txPortList

    LogEvent "Checking transmit state"

    if {[llength $txPortList] == 0} {
        ReturnStatus INTERNAL_ERROR "No transmit ports defined"
    }

    # Compile list of non-working ports.
    set badPortList [list]
    foreach txport $txPortList {
        scan $txport "%d %d %d" chassis card port
        if {[stat getTransmitState $chassis $card $port] == 0} {
            lappend badPortList $txport
        }        
    }

    # Return if everything worked.
    if {[llength $badPortList] == 0} {
        ReturnStatus NO_ERROR
    }

    after 1000

    # Try starting just the ports that failed.
    LogEvent "Retrying startTransmit on $badPortList"
    if {[ixStartTransmit badPortList] != 0} {
        # Error starting transmit.
        ReturnStatus START_TRANSMIT_FAILED
    }

    after 1000

    # Compile list of non-working ports.
    set msgPortList [list]
    foreach txport $badPortList {
        scan $txport "%d %d %d" chassis card port
        if {[stat getTransmitState $chassis $card $port] == 0} {
            lappend msgPortList [join $txport "."]
        }        
    }

    # Error if it failed again.
    if {[llength $msgPortList] != 0} {
        # Transmit not started: %1.
        ReturnStatus TRANSMIT_NOT_STARTED $msgPortList
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::CheckTransmitStarted


########################################################################################
#
# Procedure:   ixChariot::CheckTransmitStopped
#
# Description: Check hardware ports to see whether transmit has stopped.
#
# Argument(s): None.
#
# Returns:
#   NO_ERROR                    : if no error
#   INTERNAL_ERROR              : if no transmit ports defined
#   TRANSMIT_NOT_STOPPED        : if port still transmitting
#
########################################################################################

proc ixChariot::CheckTransmitStopped {} \
{
    variable txPortList

    LogEvent "Checking transmit state"

    if {[llength $txPortList] == 0} {
        ReturnStatus INTERNAL_ERROR "No transmit ports defined"
    }

    set msgPortList [list]
    foreach txport $txPortList {
        scan $txport "%d %d %d" chassis card port
        if {[stat getTransmitState $chassis $card $port]} {
            lappend msgPortList [join $txport "."]
        }        
    }

    if {[llength $msgPortList] != 0} {
        # Transmit not stopped: %1.
        ReturnStatus TRANSMIT_NOT_STOPPED $msgPortList
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::CheckTransmitStopped


########################################################################################
#
# Procedure:   ixChariot::IssueArpRequest
#
# Description: Issues ARP requests for all ports.
#
# Argument(s): waitTime - number of milliseconds to wait after issuing ARPs.
#
# Returns:
#   NO_ERROR                    : if no error
#   INTERNAL_ERROR              : if no ports defined
#   CLEAR_TIME_STAMP_FAILED     : if clearTimeStamp failed
#
########################################################################################
proc ixChariot::IssueArpRequest {{waitTime 4000}} \
{
    variable txPortList
    variable rxPortList

    LogEvent "Sending ARP Request"

    set allPorts [lsort -unique [concat $txPortList $rxPortList]]
    if {[llength $allPorts] == 0} {
        ReturnStatus INTERNAL_ERROR "No ports defined"
    }

    # We don't need this anymore, we do it from Stack Manager API.

    #if [ixClearTimeStamp allPorts] {
    #    Error clearing time stamps.
    #    ReturnStatus CLEAR_TIME_STAMP_FAILED
    #}

    #############################################################################
    #                                                                           #
    #  NOTE:                                                                    #
    #  The gateway addresses in the interface table will be zero (0.0.0.0)      #
    #  if the interfaces were configured using StackManager, which means        #
    #  That this function will have no effect.                                  #
    #                                                                           #
    #  As of IxChariot 6.10 and IxOS 4.0, the HPP DLL performs neighbor         #
    #  discovery through StackManager, and supplies the correct MAC address     #
    #  when it configures each port.                                            #
    #                                                                           #
    #  IssueArpRequest was left in place to provide backward compatiblity       #
    #  with IxOS 3.80 and IxApplifier.                                          #
    #                                                                           #
    #############################################################################

    # Check each hardware port to determine whether it has a non-zero gateway
    # address. If not, log a message and drop the port from the list of ports
    # for which we will issue ARP requests. [32618]
    #
    # Use the interface table, rather than the address table, since IxApplifier
    # no longer initializes the address table. [47339]
    set arpPorts {}
    set gatewayList {}
    foreach hwport $allPorts {
        scan $hwport "%d %d %d" chassis card port
        set nonZeroGateway 0

        # Select the interface table for this chassis/card/port.
        if {[interfaceTable select $chassis $card $port] == 0} {

            # Retrieve each interface from the interface table.
            for {set rc [interfaceTable getFirstInterface]} \
                {$rc == 0} \
                {set rc [interfaceTable getNextInterface]} \
            {
                # Retrieve each IPv4 address entry for the interface.
                for {set rc [interfaceEntry getFirstItem addressTypeIpV4]} \
                    {$rc == 0} \
                    {set rc [interfaceEntry getNextItem addressTypeIpV4]} \
                {
                    # Get the gateway address for this entry.
                    set gateway [interfaceIpV4 cget -gatewayIpAddress]
                    scan $gateway "%d.%d.%d.%d" a b c d

                    # Is it non-zero?
                    if {$a || $b || $c || $d} {

                        # Yes, add this port to the list of ports for which
                        # we will need to ARP.
                        if {!$nonZeroGateway} {
                            lappend arpPorts $hwport
                            incr nonZeroGateway
                        }

                        # Add IP address to list of gateway IP addresses.
                        lappend gatewayList $gateway
                    }
                } ;# for
            } ;# for
        } \
        else {
            LogEvent "interfaceTable select $chassis $card $port failed" 
        } ;# if
        
        if {!$nonZeroGateway} {
            LogEvent "port [list $hwport]: all gateways are zero"
        }

    } ;# foreach

    # Return if there are no ports for us to ARP.
    if {[llength $arpPorts] == 0} {
        return
    }

    # Eliminate any duplicates from the gateway IP address list.
    set gatewayList [lsort -unique $gatewayList]

    LogEvent "arpPorts:    $arpPorts"
    LogEvent "gatewayList: $gatewayList"

    # Suppress ARP learn mode on all ports. [38830]
    # This should eliminate the "ARP storm" that occurs on startup.
    foreach hwport $arpPorts {
        scan $hwport "%d %d %d" chassis card port
        if {[arpServer get $chassis $card $port] == 0} {
            arpServer config -mode arpGatewayOnly
            if {[arpServer set $chassis $card $port] != 0} {
                LogEvent "port [list $hwport]: error configuring ARP server"
            }
        } \
        else {
            LogEvent "port [list $hwport]: error getting ARP configuration"
        }
    } ;# foreach

    if [ixEnableArpResponse oneIpToOneMAC arpPorts] {
        # Error enabling ARP responses.
        ReturnStatus ENABLE_ARP_RESPONSE_FAILED
    }

    if [ixTransmitArpRequest arpPorts] {
        # Error transmitting ARP requests.
        ReturnStatus TRANSMIT_ARP_REQUEST_FAILED
    }

    # Wait for ARPs to be serviced.
    if {$waitTime > 0} {
        after $waitTime
    }

    # Report success.
    ReturnStatus NO_ERROR

} ;# ixChariot::IssueArpRequest


########################################################################################
#
# Procedure:   ixChariot::StartTransmit
#
# Description: Starts transmit on all hardware ports.
#
# Argument(s): None.
#
# Returns:
#   NO_ERROR                    : if no error
#   CLEAR_STATS_FAILED          : if clearStats failed
#   INTERNAL_ERROR              : if no transmit or receive ports defined
#   START_PACKET_GROUPS_FAILED  : if startPG failed
#   START_TRANSMIT_FAILED       : if error starting transmit
#
########################################################################################
proc ixChariot::StartTransmit {} \
{
    variable txPortList
    variable rxPortList

    LogEvent "Starting Transmission"

    #LogEvent "txPortList $txPortList"
    #LogEvent "rxPortList $rxPortList"

    if {[llength $txPortList] == 0} {
        ReturnStatus INTERNAL_ERROR "No transmit ports defined"
    }

    #if {[llength $rxPortList] == 0} {
    #    ReturnStatus INTERNAL_ERROR "No receive ports defined"
    #}

    set allPorts [lsort -unique [concat $txPortList $rxPortList]]
    #LogEvent "allPorts $allPorts"

    # Issue ARP for each transmit port.
    #IssueArpRequest

    if [ixClearStats allPorts] {
        # Error clearing statistics.
        ReturnStatus CLEAR_STATS_FAILED
    }

    if {[llength $rxPortList] != 0} {
        if [ixStartPacketGroups rxPortList] {
            # Error starting packet groups.
            ReturnStatus START_PACKET_GROUPS_FAILED
        }
    }

    if [ixStartTransmit txPortList] {
        # Error starting transmit.
        ReturnStatus START_TRANSMIT_FAILED
    }

    # Allow time for ports to start.
    #after 1000

    # Verify that transmission has started.
    #catch {CheckTransmitStarted}
    #return [CheckTransmitStarted]

    # Report success.
    ReturnStatus NO_ERROR

} ;# ixChariot::StartTransmit


########################################################################################
#
# Procedure:   ixChariot::StopTransmit
#
# Description: Stops transmit on all hardware ports.
#
# Argument(s): None.
#
# Returns:
#   NO_ERROR                    : if no error
#   INTERNAL_ERROR              : if no transmit ports defined
#   STOP_PACKET_GROUPS_FAILED   : if stopping PG failed
#   STOP_TRANSMIT_FAILED        : if error stopping transmit
#
########################################################################################
proc ixChariot::StopTransmit {} \
{
    variable txPortList
    variable rxPortList

    LogEvent "Stopping transmission"
    variable logFileTimeStamp 0

    if {[llength $txPortList] == 0} {
        ReturnStatus INTERNAL_ERROR "No transmit ports defined"
    }

    set allPorts [concat $txPortList $rxPortList]

    if [ixStopTransmit txPortList] {
        # Error stopping transmit.
        ReturnStatus STOP_TRANSMIT_FAILED
    }
    if [ixStopPacketGroups allPorts] {
        # Error stopping packet groups.
        ReturnStatus STOP_PACKET_GROUPS_FAILED
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::StopTransmit
