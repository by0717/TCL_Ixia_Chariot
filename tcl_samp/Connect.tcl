##################################################################################
# $Header: //ral_depot/products/IxChariot6.70.27/HwPairAPI/TCL/Connect.tcl#1 $
# $DateTime: 2008/06/17 13:37:46 $
# $Author: aameling $
#
# $Workfile: Connect.tcl $
#
#   Copyright © 2003-2004 by IXIA
#   All Rights Reserved.
#
#   Revision Log:
#   09-26-2003  DS  Genesis
#
# Description:
#   This file contains the proc required for both socket & chassis connections.
#
###################################################################################
#
#   PUBLIC INTERFACE:
#
#       Connect                 connect to a list of chassis.
#       OpenSocket              open a server socket from ixTclServer client.
#
#   PRIVATE INTERFACE:
#
#       AcceptStatSocketConnection  accept connection from client socket.
#       HandleStats             handle messages from client socket.
#
###################################################################################


########################################################################################
#
# Procedure:   ixChariot::Connect
#
# Description: This procedure connects to a list of chassis. An ID number is assigned to
#              the chassis in sequence starting from 1 in the order that the list is passed.
#              The first chassis in the list is assigned as the master chassis.
#
# Argument(s):
#    hostnameList - The list of hostnames or IP addresses of chassis in a chain
#    cableLength - Optional.  The length of the cables between the chassis.  If not passed in,
#                  then uses cable3feet.  Note - may be a list of lengths, one for each chassis
#                  in the chassisList.
#
# Returns:
#   NO_ERROR                    : no error
#   CHASSIS_CONNECT_TIMEOUT     : timeout connecting to chassis
#   CHASSIS_VERSION_MISMATCH    : version mismatch with chassis
#   CHASSIS_HARDWARE_CONFLICT   : hardware conflict connecting to chassis
#   CHASSIS_CONNECT_FAILED      : error connecting to chassis
#
#########################################################################################
proc ixChariot::Connect {hostnameList {cableLength 0}} \
{

    LogEvent "Connecting to $hostnameList"

    set retAddCode  [ixConnectToChassis $hostnameList]

    set errorString [ixUtils getErrorString $retAddCode]
    if {$errorString == ""} {
        set errorString "Error code $retAddCode"
    }

    switch $retAddCode "
        $::TCL_OK {
            ReturnStatus NO_ERROR
        }
        $::ixTcl_chassisTimeout {
            # Timeout connecting to chassis.
            ReturnStatus CHASSIS_CONNECT_TIMEOUT
        }
        $::ixTcl_versionMismatch {
            # Version mismatch with chassis.
            ReturnStatus CHASSIS_VERSION_MISMATCH
        }
        $::ixTcl_HardwareConflict {
            # Hardware conflict connecting to chassis.
            ReturnStatus CHASSIS_HARDWARE_CONFLICT
        }
        $::TCL_ERROR -
        default {
            # Error connecting to chassis: %1.
            ReturnStatus CHASSIS_CONNECT_FAILED [list $errorString]
        }
    "

} ;# ixChariot::Connect


########################################################################################
# Procedure:   ixChariot::OpenSocket
#
# Description: This procedure opens a server socket from the ixTclServer client
#
# Argument(s):  port - default 0, which means have the OS select one for you
#
# Returns:
#    port number if successful for client to connect on
#    -1 if not successful
########################################################################################
proc ixChariot::OpenSocket {{port 0}} \
{
    variable statSid
    variable logFile

    variable kSocketOpenError

    if [catch {socket -server ::ixChariot::AcceptStatSocketConnection $port} socketId] {
        errorMsg "Error opening socket: $socketId"
        set port $kSocketOpenError
    } else {
        set port [lindex [fconfigure $socketId -sockname] end]
        set statSid $socketId
    }
    
    LogEvent "port $port statSid $socketId"

    return $port

} ;# ixChariot::OpenSocket


########################################################################################
#                   local use procs only
########################################################################################


########################################################################################
# Procedure:   ixChariot::AcceptStatSocketConnection
#
# Description: This procedure is the callback function that accepts the open socket 
#              connection from the Chariot client for stats
#
# Argument(s): sock - statistics socket identifier.
#              addr - client IP address.
#              port - client port number.
#
# Returns:     None.
#
########################################################################################
proc ixChariot::AcceptStatSocketConnection {sock addr port} \
{
    variable logFile

    #puts "Accept $sock from $addr port $port"

    # Set up command socket to handle incoming commands.
    fconfigure $sock -buffering line -blocking 0
    fileevent $sock readable [list ::ixChariot::HandleStats $sock]

    if {![catch {open $logFile a} fileId]} {
        puts $fileId "Accept $sock from $addr port $port"
        puts $fileId "fileevent details: [fileevent $sock readable]"
        close $fileId
    }

} ;# ixChariot::AcceptStatSocketConnection


########################################################################################
# Procedure:   ixChariot::HandleStats
#
# Description: This procedure is the callback function that handles the incoming messages
#              from the client socket, such as START, STOP, etc.
#
# Argument(s): sock - statistics socket identifier.
#              pollTime - statistics polling interval, in milliseconds.
#
# Returns:
########################################################################################
proc ixChariot::HandleStats {sock {pollTime 3000}} \
{
    variable logFile
    variable enableMetrics

    if {[eof $sock] || [catch {gets $sock line}]} {
        # end of file or abnormal connection drop
        close $sock
    } else {
        LogEvent $line
        switch $line {
            "Start"
            {
                set enableMetrics $::true
                StartMetricsPoll $sock $pollTime
            }
            "Stop"
            {
                StopMetricsPoll $sock
            }
            "Shutdown"
            {
                catch {close $sock}
                set ::forever 1
            }
            default {
                catch $line errMsg
                if {![catch {open $logFile a} fileId]} {
                    puts $fileId "%$line\n>$errMsg"
                    close $fileId
                }

                if [catch {
                    puts $sock $errMsg
                    flush $sock
                }] {
                    catch {close $sock}
                    set ::forever 1
                }
            }
        } ;# switch
    } ;# else

} ;# ixChariot::HandleStats
