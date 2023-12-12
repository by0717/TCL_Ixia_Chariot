##################################################################################
# $Header: //ral_depot/products/IxChariot6.70.27/HwPairAPI/TCL/Initialize.tcl#1 $
# $DateTime: 2008/06/17 13:37:46 $
# $Author: aameling $
#
# $Workfile: Initialize.tcl $
#
#   Copyright © 2003-2006 by IXIA
#   All Rights Reserved.
#
# Authors:
#   Debby Stopp and Derek Foster.
#
# Description:
#   This file contains the namespace declaration for ixChariot procs
#
###################################################################################
#
#   PUBLIC INTERFACE:
#
#       Login                       log user into IxOS client.
#       Logout                      log user out of IxOS client.
#       Reset                       reset ixChariot namespace to well-known state.
#
#   PRIVATE INTERFACE:
#
#       bgerror                     log error for callback procedure.
#       GetIxOsMajorVersion         return IxOS major version number.
#       Is365                       check for IxOS version 3.65
#       IsVersionMin                check for minimum required IxOS version.
#       ReturnStatus                return the status of a request.
#
###################################################################################

package req IxTclHal

namespace eval ixChariot {
    variable enableMetrics      1
    variable txPortList         [list]
    variable rxPortList         [list]
    variable filterPortList     [list]
    variable firstWriteConfig   1

    variable PortInfo
    array set PortInfo          {}

    variable EndpointInfo
    array set EndpointInfo      {}

    variable statWatchList {
        framesSent framesReceived bytesSent bytesReceived transmitDuration
    }

    variable pgWatchList {
        averageLatency bigSequenceError bitRate maxLatency minLatency 
        reverseSequenceError smallSequenceError totalByteCount totalFrames 
        totalSequenceError firstTimeStamp lastTimeStamp
    }

    # Internal constants.
    set kSignatureSize          4   ;# size of packet group signature
    set kGroupIdSize            2   ;# size of packet group identifier
    set kSequenceSize           4   ;# size of packet group sequence number
    set kTimestampSize          6   ;# size of packet group timestamp

    set kEthSize                14  ;# size of Ethernet II header
    set kCrcSize                4   ;# size of Ethernet FCS

    set kIpv4Size               20  ;# size of IPv4 header
    set kIpv6Size               40  ;# size of IPv6 header
    set kTcpSize                20  ;# size of TCP header

    #
    # The packet group offset is the cumulative size of the protocol headers
    # that precede the payload of the TCP or UDP packet in the frame.
    # 
    # These numbers will increase if the packet uses IEEE 802.3 encapsulation
    # instead of Ethernet II, or if it contains VLAN or MPLS tags.
    # 
    variable IPV4_GROUP_OFFSET  [expr {$kEthSize + $kIpv4Size + $kTcpSize}]
    variable IPV6_GROUP_OFFSET  [expr {$kEthSize + $kIpv6Size + $kTcpSize}]

    # Packet group field offsets.
    variable PG_SIGNATURE       0
    variable PG_GROUP_ID        [expr {$PG_SIGNATURE + $kSignatureSize}]
    variable PG_SEQUENCE        [expr {$PG_GROUP_ID + $kGroupIdSize}]
    variable PG_TIMESTAMP       [expr {$PG_SEQUENCE + $kSequenceSize}]

    variable PG_OVERHEAD        [expr {$PG_TIMESTAMP + $kTimestampSize}]
    variable FRAME_OVERHEAD     [expr {$PG_OVERHEAD + $kCrcSize}]

    variable logFileDir         [file dirname [info script]]
    variable logFileName        [clock format [clock seconds] -format "hppTclApi%Y%m%d.log"]
    variable logFile            [file join $logFileDir $logFileName]
    variable logFileTimeStamp   0

    variable statSid            ""

    # constants, DO NOT CHANGE!
    variable kWatchId           42
    variable kSocketOpenError   -1
    variable kUdf               1

    # Port type constants.
    variable ipV4Only           1   ;# port may receive IPv4 packets only
    variable ipV6Compatible     2   ;# port may receive both IPv4 and IPv6 packets

    # Stream type constants.
    variable defaultStream      0   ;# standard stream
    variable voipStream         1   ;# voice over IP stream
    variable voipAsd            2   ;# voice over IP stream defined in an ASD

    # measureStats constants.
    variable statsDisable       0   ;# enable neither filters nor metrics
    variable statsEnable        1   ;# enable both filters and metrics
    variable statsFilter        2   ;# enable filters but not metrics

    # Return code constants.
    #enum                               value   
    #-----------------------------      ------  
    variable kRetCode
    array set kRetCode {
        NO_ERROR                        0x1000
        INTERNAL_ERROR                  0x1001
        INVALID_RETURN_CODE             0x1002
        RESERVED_1003                   0x1003
        RESERVED_1004                   0x1004
        RESERVED_1005                   0x1005
        RESERVED_1006                   0x1006
        RESERVED_1007                   0x1007
        CHASSIS_CONNECT_FAILED          0x1008
        CHASSIS_VERSION_MISMATCH        0x1009
        CHASSIS_HARDWARE_CONFLICT       0x100A
        CHASSIS_CONNECT_TIMEOUT         0x100B
        PORT_NOT_AVAILABLE              0x100C
        PORT_NO_FEATURE                 0x100D
        TAKE_OWNERSHIP_FAILED           0x100E
        STREAM_DELETE_FAILED            0x100F
        PORT_GET_FAILED                 0x1010
        PORT_SET_FAILED                 0x1011
        STREAM_GET_FAILED               0x1012
        STREAM_SET_FAILED               0x1013
        UDF_GET_FAILED                  0x1014
        UDF_SET_FAILED                  0x1015
        IPV4_GET_FAILED                 0x1016
        IPV4_SET_FAILED                 0x1017
        SDF_IMPORT_FAILED               0x1018
        STR_IMPORT_FAILED               0x1019
        IPV6_ADDRESS_IPV4_STREAM        0x101A
        IPV6_GET_FAILED                 0x101B
        IPV6_SET_FAILED                 0x101C
        INVALID_STREAM_TYPE             0x101D
        STREAM_UDF_RESERVED             0x101E
        PATTERN_TYPE_NOT_FIXED          0x101F
        PACKET_GROUP_SET_TX_FAILED      0x1020
        PACKET_GROUP_SET_RX_FAILED      0x1021
        WRITE_CONFIG_FAILED             0x1022
        LINK_DOWN                       0x1023
        INVALID_STREAM_SIZE_TYPE        0x1024
        CARD_GET_FAILED                 0x1025
        PATTERN_FILTER_SET_FAILED       0x1026
        START_TRANSMIT_FAILED           0x1027
        STOP_TRANSMIT_FAILED            0x1028
        TRANSMIT_NOT_STARTED            0x1029
        TRANSMIT_NOT_STOPPED            0x102A
        ENABLE_ARP_RESPONSE_FAILED      0x102B
        TRANSMIT_ARP_REQUEST_FAILED     0x102C
        CLEAR_TIME_STAMP_FAILED         0x102D
        CLEAR_STATS_FAILED              0x102E
        START_PACKET_GROUPS_FAILED      0x102F
        STOP_PACKET_GROUPS_FAILED       0x1030
        STAT_WATCH_CREATE_FAILED        0x1031
        STAT_WATCH_ADD_PORT_FAILED      0x1032
        STAT_WATCH_ADD_STAT_FAILED      0x1033
        STAT_WATCH_START_FAILED         0x1034
        STAT_GROUP_PORT_ADD_FAILED      0x1035
        PORT_SET_NOT_AVAILABLE          0x1036
        PORT_SET_NO_FEATURE             0x1037
        WRITE_PORT_CONFIG_FAILED        0x1038
        VOIP_PAIR_EXCEEDS_BANDWIDTH     0x1039
        IPV6_STREAM_IPV4_ENDPOINT       0x103A
        STREAM_WRITE_FAILED             0x103B
        VLAN_SET_FAILED                 0x103C
        NO_STREAMS_DEFINED              0x103D
    }

} ;# namespace ixChariot


########################################################################################
#
# Procedure:   ixChariot::LogEvent
#
# Description: This procedure logs a major event to the log file.
#
# Argument(s): msg - event message.
#
# Returns:     None.
#
########################################################################################
proc ixChariot::LogEvent {msg} \
{
    variable logFile
    variable logFileTimeStamp

    if { ![catch {open $logFile a} fileId] } {
        if {!$logFileTimeStamp} {
            puts $fileId ""
            puts $fileId [clock format [clock seconds] -format "%d-%b-%Y %H:%M:%S %Z"]
            set logFileTimeStamp 1
        }
        set procName [lindex [info level [expr [info level]-1]] 0]
        set ns "ixChariot::"
        set idx [string first $ns $procName]
        if {$idx != -1} {
            set procName [string range $procName [expr {$idx+[string length $ns]}] end]
        }
        puts $fileId "$procName: $msg"; flush $fileId
        #DumpInterfaceState $fileId
        catch {close $fileId}
    }

} ;# ixChariot::LogEvent


if {0} {

########################################################################################
#
# Procedure:   ixChariot::LogInterfaceState
#
# Description: This procedure logs the interface state.
#
# Argument(s): hwPort - hardware port to display.
#
# Returns:     None.
#
########################################################################################
proc ixChariot::LogInterfaceState {{hwPort {1 3 1}}} \
{
    variable logFile

    if { ![catch {open $logFile a} fileId] } {
        DumpInterfaceState $fileId $hwPort
        catch {close $fileId}
    }

} ;# ixChariot::LogInterfaceState


########################################################################################
#
# Procedure:   ixChariot::DumpInterfaceState
#
# Description: This procedure records interface state in the log file.
#
# Argument(s): fileId - log file stream identifier.
#              hwPort - hardware port to display.
#
# Returns:     None.
#
########################################################################################
proc ixChariot::DumpInterfaceState {fileId {hwPort {1 3 1}}} \
{

    if {$hwPort == ""} {
        variable txPortList
        variable rxPortList
        set hwPort [lindex [lsort [concat $txPortList $rxPortList]] 0]
        if {$hwPort == ""} {
            return
        }
    }

    if {[scan $hwPort "%d %d %d" ch ca po] != 3} {
        return
    }

    set stateMsg "No interfaces"
    if {[interfaceTable select $ch $ca $po] == $::TCL_OK} {
        if {[interfaceTable getFirstInterface] == $::TCL_OK} {
            if {[interfaceEntry getFirstItem addressTypeIpV4] == $::TCL_OK} {
                set macAddress [interfaceEntry cget -macAddress]
                set ipAddress  [interfaceIpV4 cget -ipAddress]
                set maskWidth  [interfaceIpV4 cget -maskWidth]
                #set stateMsg "[list $macAddress] $ipAddress/$maskWidth"
                set stateMsg "$ipAddress/$maskWidth"
            } \
            elseif {[interfaceEntry getFirstItem addressTypeIpV6] == $::TCL_OK} {
                set macAddress [interfaceEntry cget -macAddress]
                set ipAddress  [interfaceIpV6 cget -ipAddress]
                set maskWidth  [interfaceIpV6 cget -maskWidth]
                #set stateMsg "[list $macAddress] $ipAddress/$maskWidth"
                set stateMsg "$ipAddress/$maskWidth"
            }
        }
    }
    puts $fileId "[list $hwPort] $stateMsg"; flush $fileId

} ;# ixChariot::DumpInterfaceState

} ;# if {0}


########################################################################################
#
# Procedure:   ixChariot::Login
#
# Description: This procedure logs the user into the IxOS client.
#
# Argument(s): userName - login name, case sensitive
#
# Returns:
#   NO_ERROR
#
########################################################################################
proc ixChariot::Login {userName} \
{

    LogEvent "Logging in as $userName"
    ixLogin $userName
    ReturnStatus NO_ERROR

} ;# ixChariot::Login


########################################################################################
#
# Procedure:   ixChariot::Logout
#
# Description: This procedure logs the user out of the IxOS client.
#
# Argument(s): None.
#
# Returns:
#   NO_ERROR
#
########################################################################################
proc ixChariot::Logout {} \
{

    ixLogout
    ReturnStatus NO_ERROR

} ;# ixChariot::Logout


########################################################################################
# Procedure:   ixChariot::Reset
#
# Description: This procedure resets the state of the ixChariot namespace variables
#              back to a well-known state.
#
# Argument(s): None.
#
# Returns:
#   NO_ERROR
#
########################################################################################
proc ixChariot::Reset {} \
{
    variable enableMetrics      1   
    variable txPortList         [list]
    variable rxPortList         [list]
    variable firstWriteConfig   1

    variable logFileDir
    variable logFileName
    variable logFile            [file join $logFileDir $logFileName]
    variable logFileTimeStamp   0

    variable filterPortList     [list]

    variable lastStreamId
    catch {unset lastStreamId}

    variable PortInfo
    array unset PortInfo

    variable EndpointInfo
    array unset EndpointInfo

    ReturnStatus NO_ERROR

} ;# ixChariot::Reset


########################################################################################
#                   local use procs only
########################################################################################


########################################################################################
# Procedure:   bgerror
#
# Description: This procedure logs an error for a callback procedure.
#
# Argument(s): message - message to be logged.
#
# Returns:     None.
#
########################################################################################
proc bgerror {message} \
{

    if {![catch {open $ixChariot::logFile a} fileId]} {
        puts $fileId "An event-based script faulted with '$message'."
        close $fileId
    }

} ;# bgerror


########################################################################################
# Procedure:   ixChariot::GetIxOSMajorVersion
#
# Description: This procedure gets the major part of the IxOS version <ie., 3.65>
#
# Argument(s): None.
#
# Returns:     IxOS major version number.
#
########################################################################################
proc ixChariot::GetIxOSMajorVersion {} \
{
    #
    # Parse the IxOS version number instead of just grabbing the leading characters.
    # This fixes the code that broke when the version number went from 3.xx to 4.0.
    # We're using -ixTclHALVersion instead of -productVersion on Debby's recommendation.
    # (Not sure why; -productVersion is documented as far back as IxOS 3.65.) 
    # The TCL manual is vague about the distinctions between -installVersion,
    # -ixTclHALVersion, and -productVersion. [54011]
    #
    set osVersion [version cget -ixTclHALVersion]
    if {[scan $osVersion "%d.%d" major minor] < 2} {
        #
        # Throw an exception if the parse fails. This should make us more robust 
        # if the IxOS team monkeys with the version number format in a future release.
        # (The TCL Development Guide doesn't actually specify the result format,
        # and we've been burned once already!)
        #
        ReturnStatus INTERNAL_ERROR "IxOS returned invalid version number: $osVersion"
    }
    return "$major.$minor"
}


namespace eval ixChariot {
    variable ixOsVersion [GetIxOSMajorVersion]
}


########################################################################################
# Procedure:   ixChariot::IsVersionMin
#
# Description: This procedure checks the minimum IxOS required version.
#
# Argument(s): None.
#
# Returns:
#   $::true <1>  if ok
#   $::false <0> if not ok
#
########################################################################################
proc ixChariot::IsVersionMin {} \
{
    return [expr [GetIxOSMajorVersion] >= 3.65]
}


########################################################################################
# Procedure:   ixChariot::Is365
#
# Description: Because there are some major feature enhancements from 3.65 --> 3.70, this
#              procedure checks to see if this is a 3.65 install & therefore reduced
#              feature set.
#
# Argument(s): None.
#
# Returns:
#   $::true <1>  if ok
#   $::false <0> if not ok
#
########################################################################################
proc ixChariot::Is365 {} \
{
    return [expr [GetIxOSMajorVersion] == 3.65]
}


########################################################################################
#
# Procedure:   ixChariot::ReturnStatus
#
# Description: This procedure returns the status of a request.
#
# Argument(s): rcName - name of return code.
#              args - optional exception message.
#
# Returns:     Either throws an exception or else does an uplevel return
#              (returns control to the caller's caller) with a value consisting of
#              a properly formatted return status message.
#
########################################################################################
proc ixChariot::ReturnStatus {rcName args} \
{
    variable kRetCode
    variable logFile

    # Translate the return code identifier to a numeric string.
    if { [info exists kRetCode($rcName)] } {
        set retCode $kRetCode($rcName)
    } \
    else {
        set retCode $kRetCode(INVALID_RETURN_CODE)
    }

    # Process a successful return.
    if { $retCode == $kRetCode(NO_ERROR) } {
        return -code return $retCode
    }

    # Get the name of the calling procedure.
    set procName [lindex [info level [expr [info level]-1]] 0]

    # Build up the format block and a sequence of string replacement blocks.
    set fmtBlock {}
    set repBlockList ""

    if { $retCode == $kRetCode(INTERNAL_ERROR) } {
        # First parameter is procedure name.
        lappend fmtBlock "%s"
        append  repBlockList "{$procName}"

        # Second parameter is concatenated argument list.
        lappend fmtBlock "%s"
        append  repBlockList "{" [string trim [join $args]] "}"
    } \
    elseif { $retCode == $kRetCode(INVALID_RETURN_CODE) } {
        # First parameter is the procedure name.
        lappend fmtBlock "%s"
        append  repBlockList "{$procName}"

        # Second parameter is the invalid return code name.
        lappend fmtBlock "%s"
        append  repBlockList "{$rcName}"

        # Set valid return code name.
        set rcName INVALID_RETURN_CODE
    } \
    else {
        foreach arg $args {
            lappend fmtBlock "%s"
            append  repBlockList "{$arg}"
        }
    }

    # Assemble the return message (retMsg), in the format
    #   0x1nnn {{format_block} {repl_block} {repl_block} ...}
    set retInfo ""
    if { [llength $fmtBlock] } {
        append retInfo "{{" $fmtBlock "}" $repBlockList "}"
    }
    #set retMsg [string trim "$retCode $retInfo"]
    set retMsg [string trim "$retCode $rcName $retInfo"]

    # Write message to console and log file.
    set logMsg "$procName: $rcName ($retCode): $args"
    puts $logMsg

    if { ![catch {open $logFile a} fileId] } {
        puts $fileId $logMsg
        catch {close $fileId}
    }

    return -code error $retMsg

} ;# ixChariot::ReturnStatus

