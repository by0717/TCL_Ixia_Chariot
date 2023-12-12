#***************************************************************
#
#  IxChariot API SDK              File: ChrAppGroupsTest.tcl
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
#  EXAMPLE: Application Groups Test
#
#  This program loads an application group from the disk, sets
#  some attributes, replicates it, runs the test and finally
#  saves to the disk both the application groups and the test.
#
#  All attributes of this test are defined by this script.
#
#***************************************************************

#***************************************************************
# Data for the test:
# Change these for your local network if desired.
# Note: timeout is set to two minutes in seconds
#***************************************************************
set addr1 "192.168.1.10"
set addr2 "192.168.1.17"
set appGroupLoadFile "C:/Program Files(X86)/Ixia/IxChariot/Application Groups/active_FTP.iag"
set appGroupSaveFile "api_app_group.iag"
set testFile "appgroups.tst"
set appGroupDuplicateName "Duplicated app group"
set appGroupComment "Sample API app group"
set timeout 120


#***************************************************************
#
# Script Main
#
#***************************************************************

# Load the IxChariot API.
#
# NOTE:  If you are using Tcl Version 8.0.p5 or older
# then you will need to modify the following lines to load and
# use Chariot instead of ChariotExt. For example:

# load Chariot
# package require Chariot
load ChariotExt
package require ChariotExt

# Create a new test
puts "Create the test object..."
set test [chrTest new]

# Import application groups from the disk to the test
puts "Import the app groups..."
chrTest loadAppGroups $test $appGroupLoadFile

puts "Get no of app groups..."
set appGroupCount [chrTest getAppGroupCount $test]
puts "App group count: $appGroupCount"

# Get a handle to the first application group
set appGroupLoaded [chrTest getAppGroupByIndex $test 0]

# Get info about the application group
puts "Get app group name..."
set appGroupName [chrAppGroup get $appGroupLoaded APP_GROUP_NAME]
puts "App group name: $appGroupName"

puts "Get no of pairs..."
set pairCount [chrAppGroup getCount $appGroupLoaded PAIR]
puts "Pair count: $pairCount"

puts "Get no of unique network IP addresses..."
set addressCount [chrAppGroup getCount $appGroupLoaded NETWORK_ADDRESS]
puts "Network address count: $addressCount"

for {set i 0} {$i < $addressCount} {incr i} {
    set address [chrAppGroup getAddress $appGroupLoaded $i NETWORK_ADDRESS]
    puts "$i) $address"
}

puts "Get no of unique management IP addresses..."
set addressCount [chrAppGroup getCount $appGroupLoaded MANAGEMENT_ADDRESS]
puts "Management address count: $addressCount"

for {set i 0} {$i < $addressCount} {incr i} {
    set address [chrAppGroup getAddress $appGroupLoaded $i MANAGEMENT_ADDRESS]
    puts "$i) $address"
}

# The application group is owned by a test. In order to change its
# attributes, we have to remove it from the test or lock it.
# For this example, we chose to lock it.
puts "Lock the app group..."
chrAppGroup set $appGroupLoaded APP_GROUP_LOCK TRUE

puts "Set the app group comment..."
chrAppGroup set $appGroupLoaded APP_GROUP_COMMENT $appGroupComment

# Change the default IP addresses with our own.
# It's recommended to change them in reverse order.
puts "Change the second network IP address..."
chrAppGroup setAddress $appGroupLoaded 1 NETWORK_ADDRESS $addr2

puts "Change the first network IP address..."
chrAppGroup setAddress $appGroupLoaded 0 NETWORK_ADDRESS $addr1

puts "Set the app group filename..."
chrAppGroup set $appGroupLoaded APP_GROUP_FILENAME $appGroupSaveFile

# We finished the settings, so unlock the app group
puts "Unlock the app group..."
chrAppGroup set $appGroupLoaded APP_GROUP_LOCK FALSE

# Save the modified app group to the disk
chrAppGroup save $appGroupLoaded

# We want to duplicate the application group.
# In order to do that, we need a new app group object.
puts "Create a new app group object..."
set appGroupNew [chrAppGroup new]

# If we try to copy right now, we will end up with
# 2 application groups with the same name in the test.
puts "Remove the app group from the test..."
chrTest removeAppGroup $test $appGroupLoaded

puts "Copy app groups..."
chrAppGroup copy $appGroupNew $appGroupLoaded

# Change the name of the new application group
chrAppGroup set $appGroupNew APP_GROUP_NAME $appGroupDuplicateName

# Add both application groups to the test
puts "Add the app group to the test..."
chrTest addAppGroup $test $appGroupLoaded

puts "Add the app group to the test..."
chrTest addAppGroup $test $appGroupNew

puts "Run the test..."
chrTest start $test

# We have to wait for the test to stop before we can look at
# the results from it. We'll wait for 2 minutes here, then
# call it an error if it has not yet stopped.
puts "Wait for the test to stop..."
if {![chrTest isStopped $test $timeout]} {
  puts "ERROR: Test didn't stop in 2 minutes!"
  chrTest delete $test force
  return
}

# Finally, save the test
puts "=========="
puts "Save the test..."
chrTest save $test $testFile

# Clean up used resources before exiting.
# (Test will deallocate associated app groups automatically)
chrTest delete $test force

# The test was saved successfully, so we're done!
return

