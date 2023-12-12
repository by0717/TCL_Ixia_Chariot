#***************************************************************
#
#  IxChariot API SDK              File: ChrTestResults.tcl
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
#  EXAMPLE: Print Test Results
#  Loads a test from a user-specified file, then print
#  the definition and some results for each pair and
#  each multicast pair in each multicast group.
#
#  The user may also specify an interator to be used to
#  display timing record results.
#
#  All user inputs are taken from the command line. Given this,
#  this script cannot be invoked by just typing its name at
#  the command line of an MS Command Prompt window. The Tcl
#  interpreter must be specified in order for the command line
#  arguments to be correctly passed to this script.
#
#***************************************************************

#***************************************************************
# Common data
#***************************************************************
set CHR_NO_SUCH_VALUE "CHRAPI 116"


#***************************************************************
# Procedure to print common results for pairs, mpairs, or
# timing records. Show "n/a" if NO_SUCH_VALUE is returned.
#***************************************************************
proc showCommon {handle} {

  global errorCode
  global CHR_NO_SUCH_VALUE


  # These do not have NO_SUCH_VALUE as a possible return
  # so anything other than success is an error.
  if {[catch {set measTime [chrCommonResults get \
    $handle MEAS_TIME]}]} {
    puts "Get MEAS_TIME failed:"
    puts "  [chrApi getReturnMsg $errorCode]"
    return
  } else {
    set results [format "%.3f" $measTime]
    puts "  Measured time           : $results"
  }
  if {[catch {set count [chrCommonResults get \
    $handle TRANS_COUNT]}]} {
    puts "Get TRANS_COUNT failed:"
    puts "  [chrApi getReturnMsg $errorCode]"
    return
  } else {
    set results [format "%.0f" $count]
    puts "  Transaction count       : $results"
  }

  return
}

#***************************************************************
# Procedure to print results specific to pairs and mpairs.
# Show "n/a" if NO_SUCH_VALUE is returned.
#***************************************************************
proc showResults {handle}  {

  global errorCode
  global CHR_NO_SUCH_VALUE

  # These could have NO_SUCH_VALUE as a valid return,
  # depending on the specifics of the test.
  if {[catch {set trate [chrPairResults get \
    $handle TRANS_RATE]}]} {

    if {$errorCode == $CHR_NO_SUCH_VALUE} {
      puts "  Transaction rate  : n/a"
    } else {
      puts "Get TRANS_RATE failed:"
      puts "  [chrApi getReturnMsg $errorCode]"
      return
    }
  } else {
    set avg [format "%.3f" [lindex $trate 0]]
    set min [format "%.3f" [lindex $trate 1]]
    set max [format "%.3f" [lindex $trate 2]]
    puts "  Transaction rate  :"
    puts "    avg $avg   min $min   max $max"
  }

  if {[catch {set reptime [chrPairResults get \
    $handle RESP_TIME]}]} {
    if {$errorCode == $CHR_NO_SUCH_VALUE} {
      puts "  Response time     : n/a"
    } else {
      puts "Get RESP_TIME failed:"
      puts "  [chrApi getReturnMsg $errorCode]"
      return
    }
  } else {
    set avg [format "%.5f" [lindex $reptime 0]]
    set min [format "%.5f" [lindex $reptime 1]]
    set max [format "%.5f" [lindex $reptime 2]]
    puts "  Response time     :"
    puts "    avg $avg  min $min  max $max"
  }

  if {[catch {set throughput [chrPairResults get \
    $handle THROUGHPUT]}]} {
    if {$errorCode == $CHR_NO_SUCH_VALUE} {
      puts "  Throughput        : n/a"
    } else {
      puts "Get THROUGHPUT failed:"
      puts "  [chrApi getReturnMsg $errorCode]"
      return
    }
  } else {
    set avg [format "%.3f" [lindex $throughput 0]]
    set min [format "%.3f" [lindex $throughput 1]]
    set max [format "%.3f" [lindex $throughput 2]]
    puts "  Throughput        :"
    puts "    avg $avg    min $min    max $max"
  }

  if {[catch {set jitter [chrPairResults get \
    $handle JITTER]}]} {
    if {$errorCode == $CHR_NO_SUCH_VALUE} {
      puts "  Jitter            : n/a"
    } else {
      puts "Get JITTER failed:"
      puts "  [chrApi getReturnMsg $errorCode]"
      return
    }
  } else {
    set avg [format "%.3f" [lindex $jitter 0]]
    set min [format "%.3f" [lindex $jitter 1]]
    set max [format "%.3f" [lindex $jitter 2]]
    puts "  Jitter            :"
    puts "    avg $avg    min $min    max $max"
  }

  # Show results common to pairs & timing records
  showCommon $handle
}

#***************************************************************
# Procedure to print out results specific to timing records.
# Show "n/a" if NO_SUCH_VALUE is returned.
#***************************************************************
proc showTimingRec {handle} {

  global errorCode
  global CHR_NO_SUCH_VALUE

  # These should be available always in timing records
  set elapsed [chrTimingRec get $handle ELAPSED_TIME]
  set results [format "%.3f" $elapsed]
  puts "  Elapsed time      : $results"
  set inactive [chrTimingRec get $handle INACTIVE_TIME]
  set results [format "%.3f" $inactive]
  puts "  Inactive time     : $results"

  # Jitter may only be available sometimes
  if {[catch {set jitter [chrTimingRec get \
    $handle JITTER_TIME]}]} {
    if {$errorCode == $CHR_NO_SUCH_VALUE} {
      puts "  Jitter time       : n/a"
    } else {
      puts "Get JITTER_TIME failed:"
      puts "  [chrApi getReturnMsg $errorCode]"
    }
  } else {
    set results [format "%.3f" $jitter]
    puts "  Jitter time       : $results"
  }

  # Show results common to pairs, mpairs & timing records
  showCommon $handle
}


#******************************************************************
#
# Script main
#
# Command line: ChrTestResults filename ?timingRecIter?
# where:        filename is the name of the file from which
#               to load the test. If "?", display usage.
#               timingRecIter is the timing record iterator
#               to display every Nth timing record's results.
#
#******************************************************************

# Load the Chariot package
#
# NOTE:  If you are using Tcl Version 8.0.p5 or older
# then you will need to modify the following lines to load and
# use Chariot instead of ChariotExt.  For example:
# load Chariot
# package require Chariot
load ChariotExt
package require ChariotExt

# Make sure we got a test filename
# and see if there is a timing record
# iterator on the command line.
# 这行代码检查命令行参数的数量。如果参数数量为0（没有提供任何参数）、大于2（提供了超过两个参数）、或者第一个参数是问号?，则进入条件块。
if {($argc == 0) || ($argc > 2) || ([lindex $argv 0] == "?")} {
  puts "Usage: tclsh ChrTestResults filename ?timingRecIter?"
  puts " tclsh = the Tcl interpreter"
  puts " filename = test file to load"
  puts " timingRecIter = show every Nth timing rec (optional)"
  return
}
set name [lindex $argv 0]
# 总体而言，这段代码用于处理命令行参数，确保符合预期的格式，然后获取文件名和（可选的）时间记录迭代器。如果参数有误，输出使用说明。
# Get timing record iterator
if {$argc == 2} {
  set timingRecIter [lindex $argv 1]
} else {
  set timingRecIter 0
}

# Load the test
puts "Load the test..."
set test [chrTest new]
chrTest load $test $name

# Show test definition
puts "==========================="
puts "Test definition and results:"
puts "  Filename        : [chrTest get $test FILENAME]"
set units [chrTest get $test THROUGHPUT_UNITS]
puts "  Throughput units: $units"

# Need to make sure the test ran
if {[catch {set startlocalTime [chrTest get $test LOCAL_START_TIME]}]} {
  set msg [chrApi getReturnMsg $errorCode]
  puts "  Unable to get local start time: $msg"
} else {
  puts "  Start time: $startlocalTime"
}
if {[catch {set stoplocalTime [chrTest get $test LOCAL_STOP_TIME]}]} {
  set msg [chrApi getReturnMsg $errorCode]
  puts "  Unable to get local stop time: $msg"
} else {
  puts "  Stop time : $stoplocalTime"
}
puts "  How ended : [chrTest get $test HOW_ENDED]"

set pairCount [chrTest getPairCount $test]
puts "  Number of pairs   = $pairCount"
set mgroupCount [chrTest getMGroupCount $test]
puts "  Number of mgroups = $mgroupCount"

# Show pairs and their results
for {set prIndex 0} \
  {$prIndex < $pairCount} \
  {incr prIndex} {

    # Print pair definition
    puts ""
  puts "Pair [expr $prIndex+1]:"
  set pair [chrTest getPair $test $prIndex]

  set comment [chrPair get $pair COMMENT]
  puts "  Comment            : $comment"
  set addr [chrPair get $pair E1_ADDR]
  puts "  E1 address         : $addr"
  set addr [chrPair get $pair E2_ADDR]
  puts "  E2 address         : $addr"
  # Please remove comment for PROTOCOL if you are not using a VoIPHPP script
  #set protocol [chrPair get $pair PROTOCOL]
  #puts "  Protocol           : $protocol"
  # Please remove comment for SCRIPT_FILENAME and APPL_SCRIPT_NAME if you are not using a VoIP, Video or VoIPHPP script
  #set script [chrPair get $pair SCRIPT_FILENAME]
  #puts "  Script filename    : $script"
  #set script [chrPair get $pair APPL_SCRIPT_NAME]
  #puts "  Appl script name   : $script"
  set qos [chrPair get $pair QOS_NAME]
  puts "  QOS name           : $qos"

  # Show console-e1 values only if being used.
  # Please remove comment for useConsoleE1 if you are not using a VoIPHPP script
  # set useConsoleE1 [chrPair get $pair USE_CONSOLE_E1]
  #if {$useConsoleE1} {
  # set addr [chrPair get $pair CONSOLE_E1_ADDR]
  # puts "  Console-E1 address : $addr"
  # set protocol [chrPair get $pair CONSOLE_E1_PROTOCOL]
  # puts "  Console-E1 protocol: $protocol"
  #}

  # Print pair results.
  puts ""
  puts "Pair [expr $prIndex+1] results:"

  # Was there an error for this pair?
  # NO_SUCH_VALUE means there was no run error
  if {[catch {set pairError [chrCommonError getMsgNum \
    $pair]}]} {
    if {$errorCode != $CHR_NO_SUCH_VALUE} {
      puts "Get Chariot msg num for pair failed:"
      puts "  [chrApi getReturnMsg $errorCode]"
    }
  } else {
    # If there is a message number, there has to be
    # extended error info for this pair showing what
    # happened during the test run.
    puts "Pair error! Msg num = $pairError"
    puts "[chrCommonError getInfo $pair]"
  }

  # Show results for the pair.
  # Even if there was a run error, it could have results.
  showResults $pair

  # Show timing records if selected.
  set timingRecCount [chrPair getTimingRecordCount $pair]
  puts "  Number of timing records = $timingRecCount"
  if {$timingRecIter != 0 && $timingRecCount != 0} {

    puts ""
    for {set index 0} \
      {$index < $timingRecCount} \
      {incr index $timingRecIter} {

        set timingRec [chrPair getTimingRecord $pair $index]
      puts "Timing record [expr $index+1]:"
      showTimingRec $timingRec
    }
    set lastPrinted [expr $index-$timingRecIter]
    set lastIndex [expr $timingRecCount-1]
    if {$lastPrinted != $lastIndex} {

      # Always show last timing record
      set index [expr $timingRecCount-1]
      set timingRec [chrPair getTimingRecord $pair $index]
      puts "Timing record: [expr $index+1]"
      showTimingRec $timingRec
    }
  }
}

# Show mgroups & mpairs and their results
for {set mgrpIndex 0} \
  {$mgrpIndex < $mgroupCount} \
  {incr mgrpIndex} {

    # Print mgroup definition
    puts ""
  puts "MGroup [expr $mgrpIndex+1]:"
  set mgroup [chrTest getMGroup $test $mgrpIndex]

  set name [chrMGroup get $mgroup NAME]
  puts "  Name               : $name"
  set comment [chrMGroup get $mgroup COMMENT]
  puts "  Comment            : $comment"
  set addr [chrMGroup get $mgroup MULTICAST_ADDR]
  puts "  Multicast address  : $addr"
  set port [chrMGroup get $mgroup MULTICAST_PORT]
  puts "  Multicast port     : $port"
  set addr [chrMGroup get $mgroup E1_ADDR]
  puts "  E1 address         : $addr"
  set protocol [chrMGroup get $mgroup PROTOCOL]
  puts "  Protocol           : $protocol"
  set script [chrMGroup get $mgroup SCRIPT_FILENAME]
  puts "  Script filename    : $script"
  set script [chrMGroup get $mgroup APPL_SCRIPT_NAME]
  puts "  Appl script name   : $script"
  set qos [chrMGroup get $mgroup QOS_NAME]
  puts "  QOS name           : $qos"

  # Show console-e1 values only if being used.
  set useConsoleE1 [chrMGroup get $mgroup USE_CONSOLE_E1]
  if {$useConsoleE1} {
    set addr [chrMGroup get $mgroup CONSOLE_E1_ADDR]
    puts "  Console-E1 address : $addr"
    set protocol [chrMGroup get $mgroup CONSOLE_E1_PROTOCOL]
    puts "  Console-E1 protocol: $protocol"
  }

  # Show mpairs in this mgroup.
  set mpairCount [chrMGroup getMPairCount $mgroup]
  puts "  Number of mpairs = $mpairCount"
  for {set mprIndex 0} \
    {$mprIndex < $mpairCount} \
    {incr mprIndex} {

      # Print mpair definition.
      puts ""
    puts "MPair [expr $mprIndex+1]:"
    set mpair [chrMGroup getMPair $mgroup $mprIndex]
    puts "  E2 address: [chrMPair get $mpair E2_ADDR]"

    # Print mpair results.
    puts ""
    puts "MPair [expr $mprIndex+1] results:"

    # Was there an error for this mpair?
    # NO_SUCH_VALUE means there was no run error
    if {[catch {set mpairError [chrCommonError getMsgNum \
      $mpair]}]} {
      if {$errorCode != $CHR_NO_SUCH_VALUE} {
        puts "Get Chariot msg num for mpair failed:"
        puts "  [chrApi getReturnMsg $errorCode]"
      }
    } else {
      # If there is a message number, there has to be
      # extended error info for this pair showing what
      # happened during the test run.
      puts "MPair error! Msg num = $mpairError"
      puts "[chrCommonError getInfo $mpair]"
    }

    # Show results for the mpair.
    # Even if there was a run error, it could have results.
    showResults $mpair

    # Show timing record results if selected
    set timingRecCount [chrMPair getTimingRecordCount $mpair]
    puts "  Number of timing records = $timingRecCount"
    if {$timingRecIter != 0 && $timingRecCount != 0} {

      puts ""
      for {set index 0} \
        {$index < $timingRecCount} \
        {incr index $timingRecIter} {

          set timingRec [chrMPair getTimingRecord $mpair $index]
        puts "Timing record [expr $index+1]:"
        showTimingRec $timingRec
      }
      set lastPrinted [expr $index-$timingRecIter]
      set lastIndex [expr $timingRecCount-1]
      if {$lastPrinted != $lastIndex} {

        # Always show last timing record
        set index [expr $timingRecCount-1]
        set timingRec [chrMPair getTimingRecord $mpair $index]
        puts "Timing record: [expr $index+1]"
        showTimingRec $timingRec
      }
    }
  }
}

# All done!
exit



