# Load the Chariot package
#
# NOTE:  If you are using Tcl Version 8.0.p5 or older
# then you will need to modify the following lines to load and
# use Chariot instead of ChariotExt.  For example:
# load Chariot
# package require Chariot
package require csv
source "../Config/bytcl_logger_setup.tcl"
source "../Config/bytcl_csv_setup.tcl"
source "../Common/bytcl_chrTest_setup.tcl"

# set test_file_dir "D:/TCL/test_file"
# set test_file_name "test1.tst"
# set test_file_path [file join $test_file_dir $test_file_name]
# log_to_file_info $test_file_path

# chrTest load $::test $test_file_path

#***************************************************************
# Common data
#***************************************************************
set CHR_NO_SUCH_VALUE "CHRAPI 116"
set errorCode ""

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
        log_to_file_info "Get MEAS_TIME failed:"
        log_to_file_info "  [chrApi getReturnMsg $errorCode]"
        return
    } else {
        set results [format "%.3f" $measTime]
        log_to_file_info "  Measured time           : $results"
    }
    if {[catch {set count [chrCommonResults get \
        $handle TRANS_COUNT]}]} {
        log_to_file_info "Get TRANS_COUNT failed:"
        log_to_file_info "  [chrApi getReturnMsg $errorCode]"
        return
    } else {
        set results [format "%.0f" $count]
        log_to_file_info "  Transaction count       : $results"
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

    # 定义存储 avg 数据的列表
    set pair_avg_list {}
    set trate_avg_list {}
    set reptime_avg_list {}
    set throughput_avg_list {}
    set jitter_avg_list {}

    # These could have NO_SUCH_VALUE as a valid return,
    # depending on the specifics of the test.
    if {[catch {set trate [chrPairResults get \
        $handle TRANS_RATE]}]} {

        if {$errorCode == $CHR_NO_SUCH_VALUE} {
            log_to_file_info "  Transaction rate  : n/a"
        } else {
            log_to_file_info "Get TRANS_RATE failed:"
            log_to_file_info "  [chrApi getReturnMsg $errorCode]"
            return
        }
    } else {
        set trate_avg [format "%.3f" [lindex $trate 0]]
        set min [format "%.3f" [lindex $trate 1]]
        set max [format "%.3f" [lindex $trate 2]]
        log_to_file_info "  Transaction rate  :"
        log_to_file_info "    avg $avg   min $min   max $max"
        lappend pair_avg_list $trate_avg

    }

    if {[catch {set reptime [chrPairResults get \
        $handle RESP_TIME]}]} {
        if {$errorCode == $CHR_NO_SUCH_VALUE} {
            log_to_file_info "  Response time     : n/a"
        } else {
            log_to_file_info "Get RESP_TIME failed:"
            log_to_file_info "  [chrApi getReturnMsg $errorCode]"
            return
        }
    } else {
        set reptime_avg [format "%.5f" [lindex $reptime 0]]
        set min [format "%.5f" [lindex $reptime 1]]
        set max [format "%.5f" [lindex $reptime 2]]
        log_to_file_info "  Response time     :"
        log_to_file_info "    avg $avg  min $min  max $max"
        lappend pair_avg_list $reptime_avg
    }

    if {[catch {set throughput [chrPairResults get \
        $handle THROUGHPUT]}]} {
        if {$errorCode == $CHR_NO_SUCH_VALUE} {
            log_to_file_info "  Throughput        : n/a"
        } else {
            log_to_file_info "Get THROUGHPUT failed:"
            log_to_file_info "  [chrApi getReturnMsg $errorCode]"
            return
        }
    } else {
        set throughput_avg [format "%.3f" [lindex $throughput 0]]
        set min [format "%.3f" [lindex $throughput 1]]
        set max [format "%.3f" [lindex $throughput 2]]
        log_to_file_info "  Throughput        :"
        log_to_file_info "    avg $avg    min $min    max $max"
        lappend pair_avg_list $throughput_avg
    }

    # if {[catch {set jitter [chrPairResults get \
    #     $handle JITTER]}]} {
    #     if {$errorCode == $CHR_NO_SUCH_VALUE} {
    #         log_to_file_info "  Jitter            : n/a"
    #     } else {
    #         log_to_file_info "Get JITTER failed:"
    #         log_to_file_info "  [chrApi getReturnMsg $errorCode]"
    #         return
    #     }
    # } else {
    #     set jitter_avg [format "%.3f" [lindex $jitter 0]]
    #     set min [format "%.3f" [lindex $jitter 1]]
    #     set max [format "%.3f" [lindex $jitter 2]]
    #     log_to_file_info "  Jitter            :"
    #     log_to_file_info "    avg $avg    min $min    max $max"
    #     lappend pair_avg_list $jitter_avg
    # }

    # Show results common to pairs & timing records
    showCommon $handle
    # 返回存储 avg 数据的列表
    return [list $trate_avg $reptime_avg $throughput_avg  $pair_avg_list]
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
    log_to_file_info "  Elapsed time      : $results"
    set inactive [chrTimingRec get $handle INACTIVE_TIME]
    set results [format "%.3f" $inactive]
    log_to_file_info "  Inactive time     : $results"

    # Jitter may only be available sometimes
    if {[catch {set jitter [chrTimingRec get \
        $handle JITTER_TIME]}]} {
        if {$errorCode == $CHR_NO_SUCH_VALUE} {
            log_to_file_info "  Jitter time       : n/a"
        } else {
            log_to_file_info "Get JITTER_TIME failed:"
            log_to_file_info "  [chrApi getReturnMsg $errorCode]"
        }
    } else {
        set results [format "%.3f" $jitter]
        log_to_file_info "  Jitter time       : $results"
    }

    # Show results common to pairs, mpairs & timing records
    showCommon $handle
}

# Helper function to retrieve and display time information
proc showTimeInfo {test_handle varName displayName} {
    global errorCode
    global CHR_NO_SUCH_VALUE
    if {[catch {set timeVar [chrTest get $test_handle  $varName]}]} {
        set msg [chrApi getReturnMsg $errorCode]
        log_to_file_info "  Unable to get $displayName: $msg"
    } else {
        log_to_file_info "  $displayName : $timeVar"
    }
}

#***************************************************************
# Helper function to show pair information and results
proc showPairInfo {pair prIndex} {
    global errorCode
    global CHR_NO_SUCH_VALUE

    set comment [chrPair get $pair COMMENT]
    log_to_file_info "  Comment            : $comment"
    set addr [chrPair get $pair E1_ADDR]
    log_to_file_info "  E1 address         : $addr"
    set addr [chrPair get $pair E2_ADDR]
    log_to_file_info "  E2 address         : $addr"
    log_to_file_info ""
    log_to_file_info "Pair [expr $prIndex+1] results:"

    # Check for pair error
    if {[catch {set pairError [chrCommonError getMsgNum $pair]}]} {
        if {$errorCode != $CHR_NO_SUCH_VALUE} {
            log_to_file_info "Get Chariot msg num for pair failed:"
            log_to_file_info "  [chrApi getReturnMsg $errorCode]"
        }
    } else {
        # Display pair error information
        log_to_file_info "Pair error! Msg num = $pairError"
        log_to_file_info "[chrCommonError getInfo $pair]"
    }

    # # Show results for the pair
    # showResults $pair
}

#***************************************************************


# log_to_file_info "======================================================"
# log_to_file_info "Test definition and results:"
# log_to_file_info "  Filename        : [chrTest get $test FILENAME]"
# set units [chrTest get $test THROUGHPUT_UNITS]
# log_to_file_info "  Throughput units: $units"

# # Show start and stop time information
# showTimeInfo LOCAL_START_TIME "Start_time"
# showTimeInfo LOCAL_STOP_TIME "Stop_time"
# log_to_file_info "  How ended : [chrTest get $test HOW_ENDED]"

proc displayTestInfo {test_handle} {
    log_to_file_info "======================================================"
    log_to_file_info "Test definition and results:"
    log_to_file_info "  Filename        : [chrTest get $test_handle FILENAME]"
    set units [chrTest get $test_handle THROUGHPUT_UNITS]
    log_to_file_info "  Throughput units: $units"

    # Show start and stop time information
    showTimeInfo $test_handle LOCAL_START_TIME "Start_time"
    showTimeInfo $test_handle LOCAL_STOP_TIME "Stop_time"

    log_to_file_info "  How ended : [chrTest get $test_handle HOW_ENDED]"
}


proc dispalyTestResluts {test_handle} {
    # Check the number of app groups
    if {[set appgroupCount [chrTest getAppGroupCount $test_handle]] == 0} {
        log_to_file_info " No appGroup in the test"
        set pairCount [chrTest getPairCount $test_handle]
        log_to_file_info "  Number of pairs   = $pairCount"
        # Show pairs and their results
        set trate_total 0
        set reptime_total 0
        set throughput_total 0
        set jitter_total 0
        set count_total 0
        for {set prIndex 0} {$prIndex < $pairCount} {incr prIndex} {
            # Print pair definition
            set Pair_no "Pair[expr $prIndex+1]:"
            log_to_file_info $Pair_no
            set pair [chrTest getPair $test $prIndex]
            showPairInfo $pair $prIndex
            # Show results for the pair
            set pair_reuslt [showResults $pair]
            set trate_avg [lindex $pair_reuslt 0]
            set reptime_avg [lindex $pair_reuslt 1]
            set throughput_avg [lindex $pair_reuslt 2]
            # set jitter_avg [lindex $pair_reuslt 3]
            incr count_total
            incr trate_total $trate_avg
            incr reptime_total $reptime_avg
            incr throughput_total $throughput_avg
            set pair_result_list [lindex $pair_reuslt 3]
            set pair_result_with_pairNo [linsert $pair_result_list 0 {$Pair_no}]
        }
        if {$count > 0} {
            set reptime_total [expr {$reptime_total / $count_total}]
        }else {
            puts "count is 0"
            return
        }
        log_to_file_info "Trate Rate is: $trate_total"
        log_to_file_ino "Resp Time is: $reptime_total"
        log_info_file_info "ThorughPut total avg is: $throughput_total"
        return [set result_total {$trate_total $reptime_total $throughput_total}]
    } else {
        log_to_file_info "  Number of appgroups = $appgroupCount"
        # Initialize an empty list to store app groups
        set appGroupsList [list]
        # Iterate through the app groups and populate the list
        for {set i 0} {$i < $appgroupCount} {incr i} {
            lappend appGroupsList [chrTest getAppGroupByIndex $test_handle $i]
        }
        # set appGroupsList_length [llength $appGroupsList]
        # Iterate through the app groups
        set total_group_result_list {}
        foreach appGroup $appGroupsList {
            set appGroup_pairCount [chrAppGroup getCount $appGroup PAIR]
            set appGroup_fileName [chrAppGroup get $appGroup APP_GROUP_NAME]
            log_to_file_info "======================================================"
            log_to_file_info " $appGroup_fileName pair_count  = $appGroup_pairCount"
            set trate_total 0
            set reptime_total 0
            set throughput_total 0
            set jitter_total 0
            set count_total 0
            for {set pairIndex 0} {$pairIndex < $appGroup_pairCount} {incr pairIndex} {
                # Print pair definition
                log_to_file_info "Pair [expr $pairIndex+1]:"
                set pair [chrAppGroup getPair $appGroup $pairIndex]
                # Call the showPairInfo function
                showPairInfo $pair $pairIndex
                set pair_reuslt [showResults $pair]
                set trate_avg [lindex $pair_reuslt 0]
                set reptime_avg [lindex $pair_reuslt 1]
                set throughput_avg [lindex $pair_reuslt 2]
                # set jitter_avg [lindex $pair_reuslt 3]
                incr count_total
                incr trate_total $trate_avg
                incr reptime_total $reptime_avg
                incr throughput_total $throughput_avg
                set pair_result_list [lindex $pair_reuslt 3]
                set pair_result_with_pairNo [linsert $pair_result_list 0 {$appGroup_fileName $Pair_no}]
            }
            if {$count > 0} {
                set reptime_total [expr {$reptime_total / $count_total}]
            }else {
                puts "count is 0"
                return
            }
            lappend total_group_result_list [set result_total_group {$appGroup_fileName $trate_total $reptime_total $throughput_total}]
            log_to_file_info "appGroup FileName is: $appGroup_fileName "
            log_to_file_info "Trate Rate is: $trate_total"
            log_to_file_ino "Resp Time is: $reptime_total"
            log_info_file_info "ThorughPut total avg is: $throughput_total"
        }
        return $total_group_result_list
    }

}




