#***************************************************************
#
#  IxChariot API SDK              File: ChrPairsTest.tcl
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
#  EXAMPLE: Endpoint Pairs Test
#  This script creates and runs a test with just endpoint pairs,
#  then saves the test to a file.
#
#  All attributes of this test are defined by this script.
#
#***************************************************************

#***************************************************************
# Data for test:
# Change these values for your network if desired.
#***************************************************************
set testFile "chrpairstest.tst"

set pairCount 3
set e1Addrs {"localhost" "127.0.0.1" "localhost"}
set e2Addrs {"localhost" "127.0.0.1" "localhost"}
set protocols {"TCP" "RTP" "UDP"}
set scripts {"c:/Program Files/Ixia/IxChariot/Scripts/Response_Time.scr" \
  "c:/Program Files/Ixia/IxChariot/Scripts/Streaming/Realaud.scr"   \
    "c:/Program Files/Ixia/IxChariot/Scripts/Internet/SMTP.scr"}
  set timeout 5
  set maxWait 120
  set logFile "pairsTest.log"

  #***************************************************************
  # Procedure to log errors if there is extended info
  #***************************************************************
  proc pLogError {handle code where} {

  global logFile

  # Define symbols for the errors we're interested in.
  set CHR_OPERATION_FAILED "CHRAPI 108"
  set CHR_OBJECT_INVALID   "CHRAPI 112"
  set CHR_NO_SUCH_VALUE   "CHRAPI 116"
  set CHR_APP_GROUP_INVALID "CHRAPI 136"

  # Something failed: show what happened.
  puts "$where failed: [chrApi getReturnMsg $code]"

  # See if there is extended error information available.
  # It's is only meaningful for certain errors.
  if {$code == $CHR_OPERATION_FAILED ||
    $code == $CHR_OBJECT_INVALID ||
    $code == $CHR_NO_SUCH_VALUE ||
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

# Set the test filename for saving later.
puts "Set test filename..."
if {[catch {chrTest set $test FILENAME $testFile}]} {
  pLogError $test $errorCode "chrTest set FILENAME"
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
  chrPair set $pair E1_ADDR [lindex $e1Addrs $index]
  chrPair set $pair E2_ADDR [lindex $e2Addrs $index]
  chrPair set $pair PROTOCOL [lindex $protocols $index]

  # Define a script for use by this pair.
  # We need to check for errors with extended info here.
  set script [lindex $scripts $index]
  if {[catch {chrPair useScript $pair $script}]} {
    pLogError $pair $errorCode "chrPair useScript"
    return
  }

  # Add the pair to the test.
  puts "Add the pair to the test..."
  if {[catch {chrTest addPair $test $pair}]} {
    pLogError $test $errorCode "chrTest addPair"
    return
  }
}

# The test is complete, so now we can run it.
puts "Run the test..."
if {[catch {chrTest start $test}]} {
  pLogError $test $errorCode "chrTest start"
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
  return
}

# Save the test so we can show results later.
puts "Save the test..."
if {[catch {chrTest save $test}]} {
  pLogError $test $errorCode "chrTest save"
}

# We're finished!
return
