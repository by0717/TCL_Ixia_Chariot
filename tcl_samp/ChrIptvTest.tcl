#***************************************************************
#
#  IxChariot API SDK              File: ChrIptvTest.tcl
#
#  This module contains code made available by Ixia on an AS IS
#  basis.  Anyone receiving the module is considered to be 
#  licensed under Ixia copyrights to use the Ixia-provided 
#  source code in any way he or she deems fit, including copying
#  it, compiling it, modifying it, and redistributing it, with 
#  or without modifications. No license under any Ixia patents
#  or patent applications is to be implied from this copyright
#  license.
#
#  A user of the module should understand that Ixia cannot 
#  provide technical support for the module and will not be
#  responsible for any consequences of use of the program.
#
#  Any notices, including this one, are not to be removed from
#  the module without the prior written consent of Ixia.
#
#  For more information, contact:
#
#  Ixia
#  26601 W. Agoura Rd. 
#  Calabasas, CA 91302 USA
#  Web:   http://www.ixiacom.com
#  Phone: 818-871-1800
#  Fax:   818-871-1805
#
#  General Information:
#    e-mail: info@ixiacom.com
#
#  Technical Support:
#    e-mail: support@ixiacom.com
#
#
#  EXAMPLE: IPTV Test
#  This script creates and runs a test with an IPTV receiver group,
#  then saves the test to a file.
#
#  All attributes of this test are defined by this script.
#
#***************************************************************

# The name to be assigned to the test file.
variable TEST_FILE_NAME             "chriptvtest.tst"
variable LOG_FILE_NAME              "chriptvtest.log"

variable CHASSIS_ADDRESS            "10.200.117.11"

variable CLIENT_MAC_ADDRESS         "00:dd:ff:02:01:01"
variable SERVER_MAC_ADDRESS         "00:dd:ff:02:02:01"

variable CLIENT_PORT_SPEC           "$CHASSIS_ADDRESS;2;1"
variable SERVER_PORT_SPEC           "$CHASSIS_ADDRESS;2;2"

variable CLIENT_IP_ADDRESS          "172.16.1.1"
variable SERVER_IP_ADDRESS          "172.16.2.1"

variable CLIENT_GATEWAY_ADDRESS     "0.0.0.0"
variable SERVER_GATEWAY_ADDRESS     "0.0.0.0"

variable testObject

set TEST_TIMEOUT                    5
set MAX_WAIT_TIME                   120

#***************************************************************
# Converts a port specification in StackManager format to the 
# format used by the IxChariot API.
#
# @param portSpec       Aptixia port specification, in the format
#                       <chassisAddr>;<cardNo>;<portNo>
#
# @return Chariot representation of Ixia hardware address.
#***************************************************************
proc portSpecToChariotAddr {portSpec} \
{
    set portInfo    [split $portSpec ";"]
    set chassisAddr [lindex $portInfo 0]
    set cardNo      [lindex $portInfo 1]
    set portNo      [lindex $portInfo 2]
    return [format "%s / %02u / %02u" $chassisAddr $cardNo $portNo]
}


#***************************************************************
# Configures the Ixia ports using the Aptixia StackManager API.
#
# @param myHost         IP address of TestServer.
# @param myPort         TCP port number of TestServer.
# @param mySession      TestServer session object identifier.
#
# @return XML representation of the Ixia port configuration.
#***************************************************************
proc configureIxiaPorts {myHost myPort mySession} \
{
    global CLIENT_MAC_ADDRESS       SERVER_MAC_ADDRESS
    global CLIENT_PORT_SPEC         SERVER_PORT_SPEC
    global CLIENT_IP_ADDRESS        SERVER_IP_ADDRESS
    global CLIENT_GATEWAY_ADDRESS   SERVER_GATEWAY_ADDRESS

    global CHASSIS_ADDRESS

    global testObject

    # Get TestServer session object.
    set tc [::AptixiaClient::Core::Facility GetDefaultTransactionContext]
    $tc Init $myHost $myPort
    set sessionObject [::AptixiaClient::Session %AUTO% \
        -transactioncontext $tc -objectid $mySession]
    
    # Get test object from our test server session.
    set testId [$sessionObject editableTest cget -objectid]
    set testObject [::AptixiaClient::GenericTestModel %AUTO% \
        -transactioncontext $tc -objectid $testId]

    # Give it a name of our choosing.
    $testObject name Set "ChrIptvTest"

    # Add chassis to test model.
    $testObject chassisConfig chassisChain AddTail
    set chassis [$testObject chassisConfig chassisChain Get 0]
    $chassis dns Set $CHASSIS_ADDRESS
    $chassis physicalChain Set false

    # Create Client Network port group.
    set portSpec $CLIENT_PORT_SPEC
    set pg_idx [expr [$testObject portGroupList Size] -2]
    set portGroup1 [$testObject portGroupList Get $pg_idx] 
    $portGroup1 name Set "Client Network"
    $portGroup1 portList AddTail $portSpec
    
    # Set up Ethernet Stack on Client Network.
    $portGroup1 _Instantiate stack "EthernetPlugin"
    $portGroup1 stack enabled Set true
    $portGroup1 stack mac Set $CLIENT_MAC_ADDRESS
    $portGroup1 stack comment Set "Ethernet"
    set macRange [$portGroup1 stack macRangeList Get 0]
    $macRange name Set "mac-1"
    
    # Set up IP plugin on Client Network.
    $portGroup1 stack childrenList AddTail -itemtype "IpV4V6Plugin"
    set ipPlugin [$portGroup1 stack childrenList Get 0]
    $ipPlugin comment Set "IP"
    $ipPlugin rangeList AddTail
    set ipRange [$ipPlugin rangeList Get 0]
    $ipRange enabled Set true
    $ipRange name Set "ip-1"
    $ipRange ipType Set IPv4
    $ipRange ipAddress Set $CLIENT_IP_ADDRESS
    $ipRange incrementBy Set 0.0.0.1
    $ipRange prefix Set 16
    $ipRange count Set 1
    $ipRange gatewayAddress Set $CLIENT_GATEWAY_ADDRESS

    # Create Server Network port group.
    set portSpec $SERVER_PORT_SPEC
    set pg_idx [expr [$testObject portGroupList Size] -1]
    set portGroup2 [$testObject portGroupList Get $pg_idx] 
    $portGroup2 name Set "Server Network"
    $portGroup2 portList AddTail $portSpec

    # Configure Ethernet stack on Server Network.
    $portGroup2 _Instantiate stack "EthernetPlugin"
    $portGroup2 stack enabled Set true
    $portGroup2 stack mac Set $SERVER_MAC_ADDRESS
    $portGroup2 stack comment Set "Ethernet"
    set macRange [$portGroup2 stack macRangeList Get 0]
    $macRange name Set "mac-2"

    # Configure IP plugin on Server Network.
    $portGroup2 stack childrenList AddTail -itemtype "IpV4V6Plugin"
    set ipPlugin [$portGroup2 stack childrenList Get 0]
    $ipPlugin comment Set "IP"
    $ipPlugin rangeList AddTail
    set ipRange [$ipPlugin rangeList Get 0]
    $ipRange name Set "ip-2"
    $ipRange enabled Set true
    $ipRange ipType Set IPv4
    $ipRange ipAddress Set $SERVER_IP_ADDRESS
    $ipRange incrementBy Set 0.0.0.1
    $ipRange gatewayAddress Set $SERVER_GATEWAY_ADDRESS
    $ipRange prefix Set 16
    $ipRange count Set 1

    # Apply port configuration to test.
    puts "Applying configuration to test..."
    $testObject TestConfigure

    # Get XML representation of port configuration.
    puts "Getting XML representation..."
    set xmlConfig [lindex [$testObject _GetXml \
        $::AptixiaClient::XProtocolObject::eSerializationDepth::kDeep true] 0]

    return $xmlConfig

} ;# configureIxiaPorts


#***************************************************************
# Creates a channel for the test configuration.
#
# @param channelSpec    Channel specification.
#                       A list whose elements (by lindex) are:
#                       0) Channel name.
#                       1) Channel comment.
#                       2) Multicast address.
#                       3) Multicast port number.
#
# @return Handle of newly created channel object.
#***************************************************************
proc createChannel {channelSpec} \
{
    global CLIENT_IP_ADDRESS
    global CLIENT_PORT_SPEC

    set chan [chrChannel new]

    chrChannel set $chan NAME [lindex $channelSpec 0]
    chrChannel set $chan COMMENT [lindex $channelSpec 1]
    chrChannel set $chan MULTICAST_ADDR [lindex $channelSpec 2]
    chrChannel set $chan MULTICAST_PORT [lindex $channelSpec 3]
    chrChannel set $chan PROTOCOL RTP
    chrChannel set $chan E1_ADDR $CLIENT_IP_ADDRESS
    set mgmtAddr [portSpecToChariotAddr $CLIENT_PORT_SPEC]
    chrChannel set $chan CONSOLE_E1_ADDR $mgmtAddr
    chrChannel set $chan USE_E1_E2 false

    return $chan

} ;# createChannel


#***************************************************************
# Creates a pair and adds it to the specified receiver.
#
# @param receiver       Receiver to which the pair is to be added.
# @param channel        Channel with which the pair is associated.
#
# @return Handle of newly created pair object.
#***************************************************************
proc createPair {receiver channel} \
{
    set pair [chrVPair new]

    chrVPair set $pair CHANNEL $channel
    chrVPair set $pair NO_OF_TIMING_RECORDS 5
    chrVPair set $pair TIMING_RECORD_DURATION 1

    if {[catch {chrReceiver addVPair $receiver $pair}]} {
        pLogError $receiver $errorCode "chrReceiver addVPair \$receiver \$pair"
    }
    return $pair

} ;# createPair


#***************************************************************
# Creates a receiver for the test configuration.
#
# @param receiverSpec   Receiver specification.
#                       A list whose elements are:
#                       0) Receiver name.
#                       1) Receiver comment.
#
# @return Handle of newly created receiver object.
#***************************************************************
proc createReceiver {receiverSpec} \
{
    global SERVER_IP_ADDRESS
    global SERVER_PORT_SPEC

    set rcvr [chrReceiver new]

    chrReceiver set $rcvr NAME [lindex $receiverSpec 0]
    chrReceiver set $rcvr COMMENT [lindex $receiverSpec 1]
    chrReceiver set $rcvr E2_ADDR $SERVER_IP_ADDRESS
    set mgmtAddr [portSpecToChariotAddr $SERVER_PORT_SPEC]
    chrReceiver set $rcvr SETUP_E1_E2_ADDR $mgmtAddr
    chrReceiver set $rcvr USE_E1_E2 false
    chrReceiver set $rcvr NO_OF_ITERATIONS 2

    return $rcvr

} ;# createReceiver


#***************************************************************
# Configures the test.
#
# @param test           Handle of test object.
#***************************************************************
proc configureTest {test} \
{
    set TEST_DURATION  60

    set CHANNEL1_SPEC {
        "ABC"
        "Antarctic Broadcasting Corporation"
        224.0.10.1
        22400
    }
    
    set CHANNEL2_SPEC {
        "EBC"
        "Estonian Broadcasting Corporation"
        224.0.10.2
        22402
    }
    
    set CHANNEL3_SPEC {
        "LBC"
        "Latvian Broadcasting Corporation"
        224.0.10.3
        22404
    }
    
    set RECEIVER1_SPEC {
        "STB1"
        "International News Junkie"
    }
    
    # Create IPTV channels.
    set channel1 [createChannel $CHANNEL1_SPEC]
    set channel2 [createChannel $CHANNEL2_SPEC]
    set channel3 [createChannel $CHANNEL3_SPEC]
    
    # Add channels to test.
    if {[catch {chrTest addChannel $test $channel1}]} {
        pLogError $test $errorCode "chrTest addChannel \$test \$channel1"
        chrTest delete $test
        return
    }
    if {[catch {chrTest addChannel $test $channel2}]} {
        pLogError $test $errorCode "chrTest addChannel \$test \$channel2"
        chrTest delete $test
        return
    }
    if {[catch {chrTest addChannel $test $channel3}]} {
        pLogError $test $errorCode "chrTest addChannel \$test \$channel3"
        chrTest delete $test
        return
    }
    
    # Create IPTV receivers.
    set receiver1 [createReceiver $RECEIVER1_SPEC]
    
    # Create IPTV pairs.
    createPair $receiver1 $channel1
    createPair $receiver1 $channel2
    createPair $receiver1 $channel3
    
    # Add receivers to test.
    if {[catch {chrTest addReceiver $test $receiver1}]} {
        pLogError $test $errorCode "chrTest addReceiver \$test \$receiver1"
        chrTest delete $test
        return
    }

    # Set a time limit on the test.
    set runOpts [chrTest getRunOpts $test]
    chrRunOpts set $runOpts TEST_DURATION $TEST_DURATION
    chrRunOpts set $runOpts TEST_END FIXED_DURATION

} ;# configureTest


#***************************************************************
# Procedure to log errors if there is extended info.
#
# @param handle     Handle of object that provides the extended
#                   error status.
# @param code       Chariot API return code.
# @param what       String describing the operation that failed.
#***************************************************************
proc pLogError {handle code what} \
{
    global LOG_FILE_NAME
    
    # Define symbols for the errors we're interested in.
    set CHR_OPERATION_FAILED "CHRAPI 108"
    set CHR_OBJECT_INVALID   "CHRAPI 112"
    set CHR_APP_GROUP_INVALID "CHRAPI 136"

    # Something failed: show what happened.
    puts "$what failed: [chrApi getReturnMsg $code]"
    
    # See if there is extended error information available.
    # It's is only meaningful for certain errors.
    if {$code == $CHR_OPERATION_FAILED ||
        $code == $CHR_OBJECT_INVALID ||
        $code == $CHR_APP_GROUP_INVALID} {

        # Try to get the extended error information
        set rc [catch {set info [chrCommonError getInfo \
                                               $handle "ALL"]}]
        if {$rc != 0} {
            # We can ignore all non-success return codes here
            # because most should not occur (the api has been
            # initialized and the detail level is okay),
            # and the NO_SUCH_VALUE return code here means
            # there is no info available.
            set info "<None>"
        }

        set logFile [open $LOG_FILE_NAME a+]
        set timestamp [clock format [clock seconds]]
        puts $logFile "$timestamp $what failed"
        puts $logFile "$timestamp $info"
    
        # Flush forces immediate write to file
        flush $logFile
        close $logFile
    }
} ;# pLogError


#***************************************************************
# Script main
#
# catch is used when there could be extended error information,
# so we can log what happened.
#***************************************************************

# Load the Chariot API.
# We must be using TCL Version 8.4 for StackManager.
load ChariotExt
package require ChariotExt

lappend ::auto_path "c:/Program\ Files/ixia/ixchariot/aptixia/lib/common/tclclient"
package require AptixiaClient 2.0

# Create a new test.
puts "Creating the test..."
set test [chrTest new]

# Get the TestServer address, port, and object identifier for the
# active Aptixia session.
puts "Getting test server reference..."
if {[catch {chrTest getTestServerSession $test myHost myPort mySession}]} {
    pLogError $test $errorCode "chrTest getTestServerSession $test myHost myPort mySession"
    chrTest delete $test
    return
}

# Set the test filename for saving later.
puts "Setting test filename..."
if {[catch {chrTest set $test FILENAME $TEST_FILE_NAME}]} {
    pLogError $test $errorCode "chrTest set FILENAME"
    chrTest delete $test
    return
}

# Configure the Ixia ports we will use for the test.
puts "Building Ixia configuration..."
set myConfig [configureIxiaPorts $myHost $myPort $mySession]

# Import network configuration into test.
puts "Importing the ixia configuration..."
if {[catch {chrTest set $test IXIA_NETWORK_CONFIGURATION $myConfig}]} {
    pLogError $test $errorCode "chrTest set $test IXIA_NETWORK_CONFIGURATION"
    chrTest delete $test
    return
}

# Create IPTV test configuration.
puts "Building the test..."
configureTest $test

# Save the test before running it.
puts "Saving the test..."
if {[catch {chrTest save $test}]} {
    pLogError $test $errorCode "chrTest save"
}

# Start running the test.
puts "Running the test..."
chrTest start $test

#
# Wait for the test to stop.
#
# We'll check in a loop here every $TEST_TIMEOUT (5) seconds
# then call it an error after $MAX_WAIT_TIME (two minutes) if
# the test is still not stopped.
#
set timer 0
set isStopped 0
puts "Waiting for the test to stop..."
while {!$isStopped && $timer < $MAX_WAIT_TIME} {
    update idletasks
    set isStopped [chrTest isStopped $test $TEST_TIMEOUT]
    if {!$isStopped} {
        set timer [expr $timer + $TEST_TIMEOUT]
        puts "Waiting for test to stop... ($timer)"
    }
}

if {!$isStopped} {
    # Show this as a timed out error
    set rc "CHRAPI 118"
    pLogError $test $rc "chrTest isStopped"
    return
}

# Save the test so we can examine results later.
puts "Saving the results..."
if {[catch {chrTest save $test}]} {
    pLogError $test $errorCode "chrTest save"
}

# We're finished!
chrTest delete $test
return
