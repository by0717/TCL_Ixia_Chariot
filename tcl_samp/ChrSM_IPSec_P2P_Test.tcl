#***************************************************************
#
#  IxChariot API SDK              File: ChrSM_IPSec_P2P_Test.tcl
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
#  EXAMPLE: Ixia Endpoint Pairs Test
#  This script creates and runs a test with ixia endpoint pairs
#  over IPSec tunnels between ixia ports, then saves the test to a file.
#
#  All attributes of this test are defined by this script.
#
#***************************************************************


#***************************************************************
# Data for test:
# Change these values for your network if desired.
#***************************************************************

set testFile "ChrSM_IPSec_P2P_Test.tst"
set pairCount 1

set protocols "TCP"
set scripts "c:/Program Files/Ixia/IxChariot/Scripts/Response_Time.scr" 
set timeout 5
set maxWait 180
set logFile "pairsTest.log"

set CHASSIS1_IP 192.168.6.162
set e1_mgmt "192.168.6.162;1;1"
set e2_mgmt "192.168.6.162;1;2"
set e1Mgmt "192.168.6.162 / 01 / 01"
set e2Mgmt "192.168.6.162 / 01 / 02"

#***************************************************************
# Procedure to configure ixia port using Aptixia API
#***************************************************************

proc configureIxiaPorts {myHost myPort mySession e1_mgmt e2_mgmt} {
    global CHASSIS1_IP 

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
       $pgObj name Set "Client Network"
       $pgObj portList AddTail $portSpec

# Set up Ethernet Stack on "My first port group" - pgObj
       $pgObj _Instantiate stack "EthernetPlugin"
       $pgObj stack enabled Set true
       $pgObj stack mac Set "00:00:00:00:01:01"

# Set up Emulated Router Plugin
       $pgObj stack childrenList AddTail -itemtype "EmulatedRouterPlugin"
       set erpObj [$pgObj stack childrenList Get 0]
        $erpObj ipType Set "IPv4"
        $erpObj ipAddress Set "172.16.1.1"
        $erpObj incrementBy Set "0.0.0.1"
        $erpObj gatewayAddress Set "172.16.1.2"
        $erpObj prefix Set "24"

# Set up IP Plugin 
       $erpObj childrenList AddTail -itemtype "IpV4V6Plugin"
       set ippObj [$erpObj childrenList Get 0]

       $ippObj rangeList AddTail
       set iprObj [$ippObj rangeList Get 0]
       $iprObj name Set "ip-9"
       $iprObj enabled Set true
       $iprObj ipType Set IPv4
       $iprObj ipAddress Set 172.17.1.1
       $iprObj incrementBy Set 0.0.0.1
       $iprObj prefix Set 24
       $iprObj count Set 1
              
# Set up IPSec Plugin
    $ippObj childrenList AddTail -itemtype "IPSecPlugin"
    set ipsObj [$ippObj childrenList Get 0]
    
    $ipsObj ipsecNetwork AddTail
    set isnObj [$ipsObj ipsecNetwork Get 0]
       
       $isnObj testType Set "p2p"
       $isnObj role Set "Initiator"
       $isnObj emulatedSubnet Set "70.0.0.0"
       $isnObj emulatedSubnetSuffix Set "24"
       $isnObj protectedSubnet Set "80.0.0.0"
       $isnObj protectedSubnetSuffix Set "24"
       $isnObj peerPublicIP Set "172.18.1.1"       

       set iprObjId [$iprObj cget -objectid]
       $isnObj _Bind egRange $iprObj 
     
       $ipsObj ipsecPhase1 psk Set "ixvpn"

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
       $pgObj1 name Set "Server Network"
       $pgObj1 portList AddTail $portSpec

# Set up Ethernet Stack on "My second Port Group" - pgObj1
       $pgObj1 _Instantiate stack "EthernetPlugin"
       $pgObj1 stack enabled Set true
       $pgObj1 stack mac Set "00:00:00:00:02:02"

# Set up Emulated Router Plugin
    $pgObj1 stack childrenList AddTail -itemtype "EmulatedRouterPlugin"
    set erpObj [$pgObj1 stack childrenList Get 0]
        $erpObj ipType Set "IPv4"
        $erpObj ipAddress Set "172.16.1.2"
        $erpObj incrementBy Set "0.0.0.1"
        $erpObj gatewayAddress Set "172.16.1.1"
        $erpObj prefix Set "24"

# Set up IP plugin 
       $erpObj childrenList AddTail -itemtype "IpV4V6Plugin"
       set ippObj [$erpObj childrenList Get 0]
       $ippObj rangeList AddTail
       set iprObj [$ippObj rangeList Get 0]
       $iprObj name Set "ip-8"
       $iprObj enabled Set true
       $iprObj ipType Set IPv4
       $iprObj ipAddress Set "172.18.1.1"
       $iprObj incrementBy Set 0.0.0.1
       $iprObj prefix Set 24
       $iprObj count Set 1

# Set up IPSec Plugin
    $ippObj childrenList AddTail -itemtype "IPSecPlugin"
    set ipsObj [$ippObj childrenList Get 0]
   
    $ipsObj ipsecNetwork AddTail
    set isnObj [$ipsObj ipsecNetwork Get 0]
  
       $isnObj testType Set "p2p"
       $isnObj role Set "Responder"
       $isnObj emulatedSubnet Set "80.0.0.0"
       $isnObj emulatedSubnetSuffix Set "24"
       $isnObj protectedSubnet Set "70.0.0.0"
       $isnObj protectedSubnetSuffix Set "24"
       $isnObj peerPublicIP Set "172.17.1.1"

       set iprObjId [$iprObj cget -objectid]
       $isnObj _Bind egRange $iprObj 

        
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
# Script main
#
# catch is used when there could be extended error information,
# so we can log what happened.
#***************************************************************

# Load the Chariot API.
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

# Create a new test.
puts "Create the test..."
set test [chrTest new]

# Now get the current reference to the test server
puts "Getting the test server reference"
if {[catch {chrTest getTestServerSession $test myHost myPort mySession}]} {
  pLogError $test $errorCode "chrTest getTestServerSession $test myHost myPort mySession"
  chrTest delete $test
  return
}

# Set the test filename for saving later.
puts "Set test filename..."
if {[catch {chrTest set $test FILENAME $testFile}]} {
  pLogError $test $errorCode "chrTest set FILENAME"
  chrTest delete $test
  return
}


puts "Configure ixia endpoints using AptIxia..."
set myConfig [configureIxiaPorts $myHost $myPort $mySession $e1_mgmt $e2_mgmt]

puts "Importing the ixia configuration..."
if {[catch {chrTest set $test IXIA_NETWORK_CONFIGURATION $myConfig}]} {
  pLogError $test $errorCode "chrTest set $test IXIA_NETWORK_CONFIGURATION"
  chrTest delete $test
  return
}

# Define some pairs for the test.
for {set index 0} {$index < $pairCount} {incr index} {

  # Create a pair.
  puts "Create a pair..."
  set pair [chrPair new]

  # Set pair attributes from our lists.
  puts "Set pair atttributes..."
 
  chrPair set $pair COMMENT "Pair [expr $index + 1]"
  chrPair set $pair E1_ADDR "Client Network"
  chrPair set $pair E2_ADDR "Server Network"

  chrPair set $pair USE_CONSOLE_E1 True
  chrPair set $pair USE_SETUP_E1_E2 True

  chrPair set $pair CONSOLE_E1_ADDR "Use Ixia Network Configuration"
  chrPair set $pair SETUP_E1_E2_ADDR "Use Ixia Network Configuration"
  chrPair set $pair PROTOCOL $protocols


  # Define a script for use by this pair.
  # We need to check for errors with extended info here.
  set script $scripts 
  if {[catch {chrPair useScript $pair $script}]} {
    pLogError $pair $errorCode "chrPair useScript"
    chrTest delete $test
    return
  }

  # Add the pair to the test.
  puts "Add the pair to the test..."
  if {[catch {chrTest addPair $test $pair}]} {
    pLogError $test $errorCode "chrTest addPair"
    chrTest delete $test
    return
  }
}


# The test is complete, so now we can run it.
puts "Run the test..."
if {[catch {chrTest start $test}]} {
  pLogError $test $errorCode "chrTest start"
  chrTest delete $test
  return
}

# Wait for the test to stop.
# We'll check in a loop here every 5 seconds
# then call it an error after two minutes if
# the test is still not stopped.
set timer 0
set isStopped 0
puts "Waiting for the test to stop..."
while {!$isStopped && $timer < $maxWait} {

  set isStopped [chrTest isStopped $test $timeout]
  if {!$isStopped} {
    set timer [expr $timer + $timeout]
    puts "Waiting for test to stop... ($timer)"
  }
}
if {!$isStopped} {
  # Show this as a timed out error
  set rc "CHRAPI 118"
  pLogError $test $rc "chrTest isStopped"
  chrTest delete $test
  return
}

# Save the test so we can show results later.
puts "Save the test..."
if {[catch {chrTest save $test}]} {
  pLogError $test $errorCode "chrTest save"
  return
}

chrTest delete $test
# We're finished!
return
