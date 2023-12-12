#***************************************************************
#
#  IxChariot API SDK              File: ChrMGroupsTest.tcl
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
#  EXAMPLE: Multicast Groups Test
#  This script creates and runs a test with just multicast
#  groups, then saves the test to a file.
#
#  All attributes of this test are defined by this script.
#
#***************************************************************

#***************************************************************
# Data for test:
# Change these values for your network if desired.
#***************************************************************
set testFile "chrmgroupstest.tst"

set mgroupCount 2

# For IPv6 multicast test change e1Addrs to IPv6 style addresses.
set e1Addrs {"10.10.44.48" "10.10.44.48"}

# For IPv6 multicast test change mcAddrs to IPv6 style addresses. 
set mcAddrs {"230.1.1.10" "230.1.1.20"}
set mcPorts {5500 5600}

# For IPv6 multicast test change protocols to UDP6 or RTP6.
set protocols {"RTP" "UDP"}
set scripts {"c:/Program Files/Ixia/IxChariot/Scripts/Streaming/Realaud.scr" \
             "c:/Program Files/Ixia/IxChariot/Scripts/Streaming/Realaud.scr"}

set scriptVars {"number_of_timing_records"\
                "number_of_timing_records"}
set scriptVarValues {10 10}

set mpairCount 3
# For IPv6 multicast test change e2Addrs to IPv6 style addresses.
set e2Addrs {"10.10.44.48" "10.10.44.78" "10.10.44.165"\
             "10.10.44.48" "10.10.44.78" "10.10.44.165"}

set timeout 5
set maxWait 120
set logFile "mgroupsTest.log"

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
load ChariotExt
package require ChariotExt

# Create a new test.
puts "Create the test..."
set test [chrTest new]

# Set the test filename.
if {[catch {chrTest set $test FILENAME $testFile}]} {
  pLogError $test $errorCode "chrTest set FILENAME"
  return
}

# We'll set the run options to not stop
# on initialization failures
set runOpts [chrTest getRunOpts $test]
chrRunOpts set $runOpts STOP_ON_INIT_ERR 0

# Define some multicast groups for the test
for {set mgrpIndex 0} {$mgrpIndex < $mgroupCount} {incr mgrpIndex} {

  # Create an mgroup
  puts "Create a mgroup..."
  set mgroup [chrMGroup new]

  # Set mgroup attributes from our lists
  puts "Set mgroup attributes..."
  chrMGroup set $mgroup NAME "MGroup [expr $mgrpIndex + 1]"
  chrMGroup set $mgroup E1_ADDR [lindex $e1Addrs $mgrpIndex]
  set mcAddr [lindex $mcAddrs $mgrpIndex]
  chrMGroup set $mgroup MULTICAST_ADDR $mcAddr
  set mcPort [lindex $mcPorts $mgrpIndex]
  chrMGroup set $mgroup MULTICAST_PORT $mcPort
  chrMGroup set $mgroup PROTOCOL [lindex $protocols $mgrpIndex]

  # Define a script for use by this mulicast group.
  # We need to check for errors with extended info here.
  set script [lindex $scripts $mgrpIndex]
  if {[catch {chrMGroup useScript $mgroup $script}]} {
    pLogError $mgroup $errorCode "chrMGroup useScript"
    return
  }

  # Set a script variable too
  # Since we know what we're setting and the value we want
  # for it, any failures are real errors here.
  set varName [lindex $scriptVars $mgrpIndex]
  set varValue [lindex $scriptVarValues $mgrpIndex]
  chrMGroup setScriptVar $mgroup $varName $varValue

  # Define mpairs for the group
  for {set mprIndex 0} {$mprIndex < $mpairCount} {incr mprIndex} {

    # Create an mpair
    puts "Creating mpair..."
    set mpair [chrMPair new]

    # Prompt for the endpoint 2 address
    puts "Set mpair attributes..."
    set index [expr ($mgrpIndex * $mpairCount) + $mprIndex]
    chrMPair set $mpair E2_ADDR [lindex $e2Addrs $index]

    # Add the mpair to the group
    puts "Add mpair to mgroup..."
    if {[catch {chrMGroup addMPair $mgroup $mpair}]} {
      pLogError $mgroup $errorCode "chrMGroup addMPair"
      return;
    }
  }

  # Add the group to the test
  puts "Add mgroup to the test..."
  if {[catch {chrTest addMGroup $test $mgroup}]} {
      pLogError $test $errorCode "chrTest addMGroup"
      return
  }
}

# The test is complete, so now we can run it
puts "Run the test..."
chrTest start $test

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
  return
}

# Save the test so we can show results later.
puts "Save the test..."
if {[catch {chrTest save $test}]} {
  pLogError $test $errorCode "chrTest save"
}

# We're finished!
return

