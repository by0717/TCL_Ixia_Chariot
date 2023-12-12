#***************************************************************
#
#  IxChariot API SDK              File: ChrVoIPHPPTest.tcl
#
#  This module contains code made available by Ixia on an AS IS
#  basis.  Any one receiving the module is considered to be 
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
#  EXAMPLE: Hardware VoIP Pairs Test
#  This script creates and runs a test with voip hardware performance
#  pairs using ip plugin over Ixia hardware and saves the results.
#
#  All attributes of this test are defined by this script.
#
#***************************************************************

#***************************************************************
# Data for the test:
# Change these for your local network if desired.
# Note: timeout is set to two minutes in seconds
#***************************************************************
set CHASSIS1_IP 192.168.4.170
set e1Addrs "40.0.0.1"
set e2Addrs "40.0.1.1"
set e1_mgmt "192.168.6.162;1;1"
set e2_mgmt "192.168.6.162;1;2"
set e1Mgmt "192.168.6.162 / 01 / 01"
set e2Mgmt "192.168.6.162 / 01 / 02"
set gateway1 40.0.1.1
set gateway2 40.0.0.1

set testFile "ChrVoIPHPPTest.tst"
set timeout 120
set run_duration 60

#***************************************************************
# Procedure to configure ixia port using Aptixia API
#***************************************************************

proc configureIxiaPorts {myHost myPort mySession e1_mgmt e2_mgmt} {
    global CHASSIS1_IP e1Addrs e2Addrs gateway1 gateway2

    # Start testServer and use the instance invoked by ixchariot
    # ----------------------------------------------------------
    # This section of code set's 
    # the "server transaction context" 'tc' to a particular test server
    #

    set tc [::AptixiaClient::Core::Facility GetDefaultTransactionContext]
    $tc Init $myHost $myPort
    set ::mySesObj [::AptixiaClient::Session %AUTO% -transactioncontext $tc -objectid $mySession]
    
    #
    # Get existing test from our test server session
    #

    set ::myTestId [$::mySesObj editableTest cget -objectid]
    set ::myTest [::AptixiaClient::GenericTestModel %AUTO% -transactioncontext $tc -objectid $::myTestId]

    #
    # Add some chassis's into the testmodel
    # the chassis's are in the subobject pathway
    #
    #   chassisConfig -> chassisChain
    #
    $::myTest chassisConfig chassisChain AddTail
    set ccObj [$::myTest chassisConfig chassisChain Get 0]
       $ccObj dns Set "$CHASSIS1_IP" ;# set chassis name
       $ccObj cableLength Set 3
       $ccObj physicalChain Set false
       ###

# Set up first portgroup

    set portSpec "$e1_mgmt"
    set pg_idx [expr [$::myTest portGroupList Size] -2]
       set pgObj [$::myTest portGroupList Get $pg_idx] 
       $pgObj name Set "My first port group"
       $pgObj portList AddTail $portSpec

# Set up Ethernet Stack on "My first port group" - pgObj
       $pgObj _Instantiate stack "EthernetPlugin"
       $pgObj stack enabled Set true
       $pgObj stack mac Set "00:00:00:00:01:01"

# Set up IP plugin on "My first port group" - pgObj
       $pgObj stack childrenList AddTail -itemtype "IpV4V6Plugin"
       set ippObj [$pgObj stack childrenList Get 0]

       $ippObj rangeList AddTail
       set iprObj [$ippObj rangeList Get 0]
       $iprObj enabled Set true
       $iprObj ipType Set IPv4
       $iprObj ipAddress Set $e1Addrs
       $iprObj incrementBy Set 0.0.0.1
       $iprObj prefix Set 16
       $iprObj count Set 1
       $iprObj gatewayAddress Set $gateway1

              
# Add second chassis to the list

    $::myTest chassisConfig chassisChain AddTail
    set ccObj [$::myTest chassisConfig chassisChain Get 1]
       $ccObj dns Set "$CHASSIS1_IP" ;# set chassis name
       $ccObj cableLength Set 3
       $ccObj physicalChain Set false
       ###   

# Set up second portgroup
       set portSpec $e2_mgmt
       set pg_idx [expr [$::myTest portGroupList Size] -1]
       set pgObj1 [$::myTest portGroupList Get $pg_idx] 
       $pgObj1 name Set "My Second Port Group"
       $pgObj1 portList AddTail $portSpec

# Set up Ethernet Stack on "My second Port Group" - pgObj1
       $pgObj1 _Instantiate stack "EthernetPlugin"
       $pgObj1 stack enabled Set true
       $pgObj1 stack mac Set "00:00:00:00:02:02"

# Set up IP plugin on "My second Port Group" - pgObj1
         $pgObj1 stack childrenList AddTail -itemtype "IpV4V6Plugin"
       set ippObj [$pgObj1 stack childrenList Get 0]
         $ippObj rangeList AddTail
       set iprObj [$ippObj rangeList Get 0]
       $iprObj enabled Set true
       $iprObj ipType Set IPv4
       $iprObj ipAddress Set $e2Addrs
       $iprObj incrementBy Set 0.0.0.1
       $iprObj gatewayAddress Set $gateway2
         $iprObj prefix Set 16
         $iprObj count Set 1
        
# prompt $interactive "hit return to TestConfigure"
       $::myTest TestConfigure ;# applied config on ports

    # All enums for objects are pre-defined within the object class as 
    # read-only class variables, like
    # 'kDeep' 'kShallow' etc...
    set xml1 [lindex [$::myTest _GetXml \
       $::AptixiaClient::XProtocolObject::eSerializationDepth::kDeep \
        true] 0]
    
       puts stdout $xml1
       return $xml1
}


#***************************************************************
# Procedure to log errors if there is extended info
#***************************************************************
proc pLogError {handle code where} {

  global logFile

  # Define symbols for the errors we're interested in.
  set CHR_OPERATION_FAILED "CHRAPI 108"
  set CHR_OBJECT_INVALID   "CHRAPI 112"
  set CHR_APP_GROUP_INVALID "CHRAPI 136"

  # Something failed: show what happened.
  puts "$where failed: [chrApi getReturnMsg $code]"

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
      # because most should not occur (the api's been
      # initialized and the detail level is okay),
      # and the NO_SUCH_VALUE return code here means
      # there is no info available.
      set info "<None>"
    }
    set logFile [open $logFile a+]
    set timestamp [clock format [clock seconds]]
    puts $logFile "$timestamp $where failed"
    puts $logFile "$timestamp $info"

    # Flush forces immediate write to file
    flush $logFile
  }
}

#***************************************************************
#
# Script Main
#
# The numbers is parentheses in the comments refer to the
# Program Notes section of the Chariot API Programming Guide.
#
#***************************************************************

# (1)
# You must load the Chariot package before you can use any
# of its commands. If this fails, detailed information about
# the reason is printed and is appended to $errorInfo.
#
# NOTE:  If you are using Tcl Version 8.0.p5 or older
# then you will need to modify the following lines to load and
# use Chariot instead of ChariotExt.  For example:
# load Chariot
# package require Chariot
lappend ::auto_path "c:/Program\ Files/ixia/ixchariot/aptixia/lib/common/tclclient"
load ChariotExt
package require ChariotExt
package require AptixiaClient 2.0

# (2)
# You must create a test object to define a new test
# or to load an existing test from disk.
puts "Create the test..."
set test [chrTest new]

# (3)
# Now get the current reference to the test server
puts "Getting the test server reference"
if {[catch {chrTest getTestServerSession $test myHost myPort mySession}]} {
  pLogError $test $errorCode "chrTest getTestServerSession $test myHost myPort mySession"
  chrTest delete $test
  return
}

# (4)
# Set the test filename for saving later.
puts "Set test filename..."
if {[catch {chrTest set $test FILENAME $testFile}]} {
  pLogError $test $errorCode "chrTest set FILENAME"
  chrTest delete $test
  return
}


# (5)
# You must create a pair object in order to define it.
puts "Create the hardware pair..."
set pair [chrHardwareVoipPair new]

# (6)
# Once you have a pair, you can define its attributes.
puts "Set required pair attributes..."
chrPair set $pair E1_ADDR $e1Addrs E2_ADDR $e2Addrs

puts "Set port mgmt address for endpoint 1..."
chrPair set $pair CONSOLE_E1_ADDR $e1Mgmt

puts "Set port mgmt address for endpoint 2..."
chrPair set $pair SETUP_E1_E2_ADDR $e2Mgmt


# (7)
# Setting VoIP parameters that are supported by VoIP hardware pairs.
set test_codec "G723.1A"
set test_datagram_delay 60
set test_source_port 1129
set test_dest_port 21345
set test_concurrent_calls 555

puts "Setting codec to $test_codec"
chrVoIPPair set $pair CODEC $test_codec

puts "Setting datagram delay to $test_datagram_delay"
chrVoIPPair set $pair DATAGRAM_DELAY $test_datagram_delay

puts "Setting UDP source port to $test_source_port"
chrVoIPPair set $pair SOURCE_PORT_NUMBER $test_source_port

puts "Setting UDP destination port to $test_dest_port"
chrVoIPPair set $pair DEST_PORT_NUMBER $test_dest_port

puts "Setting concurrent voice streams to $test_concurrent_calls"
chrHardwareVoipPair set $pair CONCURRENT_VOICE_STREAMS $test_concurrent_calls
puts "Concurrent voice streams were set to: [chrHardwareVoipPair get $pair CONCURRENT_VOICE_STREAMS]"
if {$test_concurrent_calls != [chrHardwareVoipPair get $pair CONCURRENT_VOICE_STREAMS]} { 
    puts "FAILED. Values didn't match." 
}

# (8)
# Now that the pair is defined, you can add it to the test.
puts "Add the pair to the test..."
chrTest addPair $test $pair

puts "Set run options for batch mode..."
set run_opts [chrTest getRunOpts $test]
chrRunOpts set $run_opts REPORTING_TYPE "BATCH"

puts "Set run options to run for $run_duration seconds."
chrRunOpts set $run_opts TEST_END "FIXED_DURATION"
chrRunOpts set $run_opts TEST_DURATION $run_duration

puts "Configure ixia endpoints using AptIxia..."
set myConfig [configureIxiaPorts $myHost $myPort $mySession $e1_mgmt $e2_mgmt]

puts "Importing the ixia configuration..."
if {[catch {chrTest set $test IXIA_NETWORK_CONFIGURATION $myConfig}]} {
  pLogError $test $errorCode "chrTest set $test IXIA_NETWORK_CONFIGURATION"
  chrTest delete $test
  return
}


# (9)
# We have a test defined, so now we can run it.
puts "Run the test..."
if {[catch {chrTest start $test}]} {
  pLogError $test $errorCode "chrTest start"
  return
}

# (10)
# We have to wait for the test to stop before we can look at
# the results from it. We'll wait for 2 minutes here, then
# call it an error if it has not yet stopped.
puts "Wait for the test to stop...$timeout seconds..."
if {![chrTest isStopped $test $timeout]} {
  puts "ERROR: Test didn't stop in 2 minutes!"
  return
}

# (11)
# Finally, let's save the test so we can look at it again.
puts "Save the test..."
chrTest save $test $testFile

# The test was saved successfully, so we're done!
return

