#***************************************************************
#get the yaml data and logger
#***************************************************************
# Source the file containing the logger setup function
source "../Config/bytcl_logger_setup.tcl"
source "../Config/bytcl_yaml_setup.tcl"
source "../Config/bytcl_filePath_setup.tcl"
source "../Common/bytcl_chrErrorCode_setup.tcl"

# set file_yaml_name "chariot_set.yml"
# set file_yaml_path [file join $Yaml_Path $file_yaml_name]
# log_to_file_info "The yaml file path is: $file_yaml_path"
# set yaml_data_dict [get_yaml_data $file_yaml_path]
# log_to_file_info $yaml_data_dict
#***************************************************************
# Data for test:
# Change these values for your network if desired.
#***************************************************************
# set testFile "chrpairstest.tst"

# set pairCount [dict get $yaml_data_dict  chariot_set pairs_count]
# set e1Addrs [dict get $yaml_data_dict chariot_set endpoint_addr endpoint1]
# set e2Addrs [dict get $yaml_data_dict chariot_set endpoint_addr endpoint2]
# set protocols [dict get $yaml_data_dict chariot_set protocols]
# set protocol [lindex $protocols 0]
# #TCP:0 UDP:1 RTP:2
# # set varType [info vars $protocols ]
# set scripts [dict get $yaml_data_dict chariot_set test_scripts]
# set High_Performance_Throughput_scipt [dict get $yaml_data_dict chariot_set test_scripts hpth_script_file]
# set time_duration [dict get $yaml_data_dict chariot_set time_duration]
# set maxWait [expr $time_duration + 30]
# log_to_file_info ""
# log_to_file_info "***********************Chariot Pairs Set Info****************************************"
# log_to_file_info "endpoint1: $e1Addrs"
# log_to_file_info "endpoint2: $e2Addrs"
# log_to_file_info "pairs_counts: $pairCount"
# log_to_file_info "choose scipt is: $scipt"
# log_to_file_info "choose protocol is: $protocol"
# log_to_file_info "***********************Chariot Pairs Set Info****************************************"
# set pairCount 3
# set e1Addrs {"localhost" "127.0.0.1" "localhost"}
# set e2Addrs {"localhost" "127.0.0.1" "localhost"}
# set protocols {"TCP" "RTP" "UDP"}
# set scripts {"c:/Program Files/Ixia/IxChariot/Scripts/Response_Time.scr" \
#              "c:/Program Files/Ixia/IxChariot/Scripts/Streaming/Realaud.scr"   \
#              "c:/Program Files/Ixia/IxChariot/Scripts/Internet/SMTP.scr"}
# set timeout 5
# set maxWait 120
# set logFile "pairsTest.log"

#*****************************************************************************************************************
#
# Script main
# Setup some functions to set chariot pasirs attributes
#*****************************************************************************************************************
# 这个函数接受 pairCount（pairs数量）、e1Addrs、e2Addrs、protocols 和 scripts 这些参数。
# 这个函数现在会在循环中创建多个pair，然后将它们存储在列表pairs中，最后返回这个列表，包含所有创建的pair对象。
# 如果想要每个 pair 具有不同的属性，需要确保 e1Addrs、e2Addrs、protocols 和 scripts 是列表，
# 且列表长度与 pairCount 相同，以便能够为每个 pair 分配不同的值。
#*****************************************************************************************************************
# # Create a new test.
# puts "Create the test..."
# set test [chrTest new]

proc createPairs_by_list {pairCount e1Addrs e2Addrs protocols scripts} {
    set pairs {}
    for {set index 0} {$index < $pairCount} {incr index} {
        # Create a pair.
        log_info_file_info "Create a pair..."
        set pair [chrPair new]

        # Set pair attributes from our lists.
        log_info_file_info "Set pair attributes..."
        chrPair set $pair COMMENT "Pair [expr $index + 1]"
        chrPair set $pair E1_ADDR [lindex $e1Addrs $index]
        chrPair set $pair E2_ADDR [lindex $e2Addrs $index]
        chrPair set $pair PROTOCOL [lindex $protocols $index]

        # Define a script for use by this pair.
        # We need to check for errors with extended info here.
        set script [lindex $scripts $index]
        if {[catch {chrPair useScript $pair $script}]} {
            pLogError $pair $errorCode "chrPair useScript"
            return -code error "Failed to create pair"
        }

        lappend pairs $pair ;# Store the created pair in a list
    }
    log_info_file_info "Creat Pairs Finished"
    return $pairs ;# Return the list of created pairs
}
#*****************************************************************************************************************
# 这个函数接受 pairCount（pairs数量）、e1Addrs、e2Addrs、protocols 和 scripts 这些参数。
# 这个函数现在会在循环中创建多个pair，然后将它们存储在列表pairs中，最后返回这个列表，包含所有创建的pair对象。
#*****************************************************************************************************************
proc creatPairs_by_copy {pairCount  e1Addrs e2Addrs protocol script} {
    set pairs {}
    log_info_file_info "Creat one pair"
    set original_pair [chrPair new]
    chrPair set $original_pair COMMENT "Pair1"
    chrPair set $original_pair E1_ADDR $e1Addrs E2_ADDR $e2Addrs
    chrPair set $original_pair PROTOCOL $protocol
    if {[catch {chrPair useScript $original_pair $script}]} {
        pLogError $original_pair $errorCode "chrPair useScript"
        return
    }
    lappend pairs $original_pair
    for {set index 1} {$index < $pairCount} {incr index}{
        # Set pair attributes from our lists.
        set pair [chrPair new]
        chrPair set $pair COMMENT "Pair [expr $index + 1]"
        log_info_file_info "Cpoy Pairs... [expr $index]"
        chrPair copy $pair $original_pair
        lappend pairs $pair
    }
    log_info_file_info "Creat Pairs Finished"
    return $pairs
}

# 从pairs 中获取pair 用foreach item $pairs{ ......}

proc creatPair_by_single {e1Addrs e2Addrs protocols script} {
    log_info_file_info "Creat one pair"
    set original_pair [chrPair new]
    chrPair set $original_pair COMMENT "Pair1"
    chrPair set $original_pair E1_ADDR $e1Addrs E2_ADDR $e2Addrs
    chrPair set $original_pair PROTOCOL
    if {[catch {chrPair useScript $original_pair $script}]} {
        pLogError $original_pair $errorCode "chrPair useScript"
        return
    }
    return $pair
}
