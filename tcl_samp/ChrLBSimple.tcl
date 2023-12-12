#***************************************************************
#
#  IxChariot API SDK              File: ChrLBSimple.tcl
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
#  EXAMPLE: Your First Script
#
#  This script creates and runs a simple loopback test using
#  the File Send, Short Connection script, prints some results,
#  and saves it to disk.
#
#  All attributes of this test are defined by this script.
#
#***************************************************************

#***************************************************************
# Data for the test:
# Change these for your local network if desired.
# Note: timeout is set to two minutes in seconds
#***************************************************************
set e1 "localhost"
set e2 "localhost"
set script   "c:/Program Files/Ixia/IxChariot/Scripts/Throughput.scr"
set testFile "lbtest.tst"
set timeout 120


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
load ChariotExt
package require ChariotExt

# (2)
# You must create a test object to define a new test
# or to load an existing test from disk.
puts "Create the test..."
set test [chrTest new]

# (3)
# You must create a pair object in order to define it.
puts "Create the pair..."
set pair [chrPair new]

# (4)
# Once you have a pair, you can define its attributes.
puts "Set required pair attributes..."
chrPair set $pair E1_ADDR $e1 E2_ADDR $e2

# (5)
# You must define a script for use in the test.
puts "Use a script..."
chrPair useScript $pair $script

# (6)
# Now that the pair is defined, you can add it to the test.
puts "Add the pair to the test..."
chrTest addPair $test $pair

# (7)
# We have a test defined, so now we can run it.
puts "Run the test..."
chrTest start $test

# (8)
# We have to wait for the test to stop before we can look at
# the results from it. We'll wait for 2 minutes here, then
# call it an error if it has not yet stopped.
puts "Wait for the test to stop..."
if {![chrTest isStopped $test $timeout]} {
  puts "ERROR: Test didn't stop in 2 minutes!"
  chrTest delete $test force
  return
}

# (9)
# Let's print out how we defined the test before printing
# results from running it. Since we have the pair handle from
# when we created it, we don't need to get it from the test.
puts "==========="
puts "Test setup:\n----------"
puts "Number of pairs = [chrTest getPairCount $test]"

puts "E1 address      : [chrPair get $pair E1_ADDR]"
puts "E2 address      : [chrPair get $pair E2_ADDR]"

# We didn't set the protocol, but let's show it anyway.
puts "Protocol        : [chrPair get $pair PROTOCOL]"

# We'll show both the script filename and
# the application script name.
puts "Script filename : [chrPair get $pair SCRIPT_FILENAME]"
puts "Appl script name: [chrPair get $pair APPL_SCRIPT_NAME]"

# (10)
# Now let's get some results:
# the number of timing records and
# the throughput (avg, min, max)
puts ""
puts "Test results:\n------------"
puts "Number of timing records = \
[chrPair getTimingRecordCount $pair]"

# (11)
# We're not going to check for "No such value" here,
# although we should. This return code signals that
# the requested result is not available for this
# particular test. These kinds of results are shown
# as "n/a" in the Chariot console display. In this case,
# though, we should be able to get throughput. We'll let
# anything other than the result be handled as an error.
set throughput [chrPairResults get $pair THROUGHPUT]

# We'll format these to look like the way the Chariot
# console displays these kinds of numbers.
set avg [format "%.3f" [lindex $throughput 0]]
set min [format "%.3f" [lindex $throughput 1]]
set max [format "%.3f" [lindex $throughput 2]]
puts "Throughput:"
puts "  avg $avg  min $min  max $max"

# (12)
# Finally, let's save the test so we can look at it again.
puts "=========="
puts "Save the test..."
chrTest save $test $testFile

# (13)
# Clean up used resources before exiting.
# (Test will deallocate associated pairs automatically)
chrTest delete $test force

# The test was saved successfully, so we're done!
return

