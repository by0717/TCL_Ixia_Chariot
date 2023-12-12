#***************************************************************
#
#  IxChariot API SDK              File: Chr802_11PayloadTest.tcl
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
#
#  This program creates and runs a simple loopback test that
#  uses the 802.11 and Script Embedded Payload features that
#  were added in IxChariot 6.0.
#
#  All attributes of this test are defined by this script.
#
#***************************************************************

#***************************************************************
# Data for the test:
# Change these for your local network if desired.
#***************************************************************
set e1 "localhost"
set e2 "localhost"
set script   "c:/Program Files/Ixia/IxChariot/Scripts/Throughput.scr"
set testFile "Chr802_11PayloadTest.tst"
set timeout 120
set sendDataTypeName     "send_datatype"
set embeddedPayload [binary format "a*xa*" "This is a sample" "embedded payload"]
set CHR_NO_SUCH_VALUE "CHRAPI 116"
set logFile "Chr802_11PayloadTest.log"


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
#***************************************************************

# You must load the Chariot package before you can use any
# of its commands. If this fails, detailed information about
# the reason is printed and is appended to $errorInfo.
#
# NOTE:  If you are using Tcl Version 8.0.p5 or older
# then you will need to modify the following lines to load and
# use Chariot instead of ChariotExt.  For example:
# load Chariot
# package require Chariot
load ChariotExt
package require ChariotExt

# NOTE:  The Script Embedded Payload feature requires ChariotExt

# Create a new test.
puts "Create the test..."
if {[catch {set test [chrTest new]}]} {
  pLogError NULL $errorCode "chrTest new"
  return
}

# Create a new pair.
puts "Create the pair..."
if {[catch {set pair [chrPair new]}]} {
  pLogError NULL $errorCode "chrPair new"
  return
}

# Define the attributes of the pair.
puts "Set required pair attributes..."
if {[catch {chrPair set $pair E1_ADDR $e1 E2_ADDR $e2}]} {
  pLogError $pair $errorCode "chrPair set E1_ADDR E2_ADDR"
  return
}

# Define a script for use in the test.
puts "Use a script..."
if {[catch {chrPair useScript $pair $script}]} {
  pLogError $pair $errorCode "chrPair useScript"
  return
}

# Set the Script Embedded Payload.
puts "Set the Script Embedded Payload..."
if {[catch {chrPair setScriptEmbeddedPayload $pair $sendDataTypeName $embeddedPayload}]} {
  pLogError $pair $errorCode "chrPair setScriptEmbeddedPayload"
  return
}

# Add the pair to the test.
puts "Add the pair to the test..."
if {[catch {chrTest addPair $test $pair}]} {
  pLogError $test $errorCode "chrTest addPair"
  return
}

# Run the test
puts "Run the test..."
if {[catch {chrTest start $test}]} {
  pLogError $test $errorCode "chrTest start"
  return
}

# Wait for the test to stop before we can look at the
# results from it. We'll wait for 2 minutes here, then
# call it an error if it has not yet stopped.
puts "Wait for the test to stop..."
if {![chrTest isStopped $test $timeout]} {
  puts "ERROR: Test didn't stop in 2 minutes!"
  chrTest delete $test force
  return
}

# Use the 802.11 feature to get the RSSI and BSSID values.
# Note that these values are retrieved by Endpoint 1 for     
# regular scripts and by Endpoint 2 for streaming scripts.

# Print the average, min and max values of RSSI
if {[catch {set rssi [chrPairResults get $pair RSSI_E1]}]} {
  if {$errorCode == $CHR_NO_SUCH_VALUE} {
    puts "No valid RSSI values for Endpoint 1"
  } else {
      pLogError $test $errorCode "chrPairResults get RSSI_E1"
      return
  }
} else {
    set avg [string trimleft [format "%5.0f" [lindex $rssi 0]]]
    set min [string trimleft [format "%5.0f" [lindex $rssi 1]]]
    set max [string trimleft [format "%5.0f" [lindex $rssi 2]]]
    puts "RSSI for Endpoint 1:"
    puts "Average: $avg dBm    Minimum: $min dBm    Maximum: $max dBm"
}

if {[catch {set rssi [chrPairResults get $pair RSSI_E2]}]} {
  if {$errorCode == $CHR_NO_SUCH_VALUE} {
    puts "No valid RSSI values for Endpoint 2"
  } else {
      pLogError $test $errorCode "chrPairResults get RSSI_E2"
      return
  }
} else {
    set avg [string trimleft [format "%5.0f" [lindex $rssi 0]]]
    set min [string trimleft [format "%5.0f" [lindex $rssi 1]]]
    set max [string trimleft [format "%5.0f" [lindex $rssi 2]]]
    puts "RSSI for Endpoint 2:"
    puts "Average: $avg dBm    Minimum: $min dBm    Maximum: $max dBm"
}

# Get the RSSI and BSSID values of the first timing record
if {[catch {set timingRec [chrPair getTimingRecord $pair 0]}]} {
  pLogError $pair $errorCode "chrPair getTimingRecord"
  return
}

puts "RSSI and BSSID values for the first timing record:"
if {[catch {set rssi [chrTimingRec get $timingRec RSSI_E1]}]} {
  if {$errorCode == $CHR_NO_SUCH_VALUE} {
    puts "RSSI for Endpoint 1: N/A"
  } else {
      pLogError $pair $errorCode "chrTimingRec get RSSI_E1"
      return
  }
} else {
    puts "RSSI for Endpoint 1: [string trimleft [format "%5.0f" $rssi]] dBm"
}

if {[catch {set bssid [chrTimingRec get $timingRec BSSID_E1]}]} {
  if {$errorCode == $CHR_NO_SUCH_VALUE} {
    puts "BSSID for Endpoint 1: N/A"
  } else {
      pLogError $pair $errorCode "chrTimingRec get BSSID_E1"
      return
  }
} else {
    puts "BSSID for Endpoint 1: $bssid"
}

if {[catch {set rssi [chrTimingRec get $timingRec RSSI_E2]}]} {
  if {$errorCode == $CHR_NO_SUCH_VALUE} {
    puts "RSSI for Endpoint 2: N/A"
  } else {
      pLogError $pair $errorCode "chrTimingRec get RSSI_E2"
      return
  }
} else {
    puts "RSSI for Endpoint 2: [string trimleft [format "%5.0f" $rssi]] dBm"
}

if {[catch {set bssid [chrTimingRec get $timingRec BSSID_E2]}]} {
  if {$errorCode == $CHR_NO_SUCH_VALUE} {
    puts "BSSID for Endpoint 2: N/A"
  } else {
      pLogError $pair $errorCode "chrTimingRec get BSSID_E2"
      return
  }
} else {
    puts "BSSID for Endpoint 2: $bssid"
}

# Finally, let's save the test so we can look at it again.
puts "=========="
puts "Save the test..."
if {[catch {chrTest save $test $testFile}]} {
  pLogError $test $errorCode "chrTest save"
  return
}

# Clean up used resources before exiting.
# (Test will deallocate associated pairs automatically)
chrTest delete $test force

# The test was saved successfully, so we're done!
return

