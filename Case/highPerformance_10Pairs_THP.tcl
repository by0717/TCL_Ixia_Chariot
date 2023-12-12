source "../Config/bytcl_logger_setup.tcl"
source "../Config/bytcl_csv_setup.tcl"
source "../Common/bytcl_chrTest_setup.tcl"
source "../Common/bytcl_chrPairs_setup.tcl"
source "../Config/bytcl_yaml_setup.tcl"
source "../Config/bytcl_filePath_setup.tcl"
source "../Common/bytcl_chrErrorCode_setup.tcl"
source "../Common/bytcl_chrTestResult_setup.tcl"


# 导入yaml 文件自定义的相关
set file_yaml_name "chariot_set.yml"
set file_yaml_path [file join $Yaml_Path $file_yaml_name]
log_to_file_info "The yaml file path is: $file_yaml_path"
set yaml_data_dict [get_yaml_data $file_yaml_path]
# log_to_file_info $yaml_data_dict

set pairCount [dict get $yaml_data_dict  chariot_set pairs_count]
set e1Addrs [dict get $yaml_data_dict chariot_set endpoint_addr endpoint1]
set e2Addrs [dict get $yaml_data_dict chariot_set endpoint_addr endpoint2]
set protocols [dict get $yaml_data_dict chariot_set protocols]
set tcp_protocol [lindex $protocols 0]
# TCP:0 UDP:1 RTP:2
# set varType [info vars $protocols ]
set scripts [dict get $yaml_data_dict chariot_set test_scripts]
# scripts list
set High_Performance_Throughput_scipt [dict get $yaml_data_dict chariot_set test_scripts hpth_script_file]
# high_perfomeance_throughput_scipt
set time_duration [dict get $yaml_data_dict chariot_set time_duration]
set time_out [dict get $yaml_data_dict chariot_set time_out]
set maxWait [expr $time_duration + $time_out]
set timeout [dict get $yaml_data_dict chariot_set timeout]

log_to_file_info ""
log_to_file_info "***********************Chariot Pairs Set Info****************************************"
log_to_file_info "endpoint1: $e1Addrs"
log_to_file_info "endpoint2: $e2Addrs"
log_to_file_info "pairs_counts: $pairCount"
log_to_file_info "choose scipt is: $scipt"
log_to_file_info "choose protocol is: $protocol"
log_to_file_info "***********************Chariot Pairs Set Info****************************************"

# （1）加载Chariot包 直接导入chrTest setup
# （2）创建测试对象 直接导入chrTest setup 中的test 对象

#  (3) 设置test 属性
set runOpts [chrTest getRunOpts $::test]
chrRunOpts set $runOpts STOP_ON_INIT_ERR 1
chrRunOpts set $runOpts TEST_END FIXED_DURATION
chrRunOpts set $runOpts TEST_DURATION $time_duration; #设置测试运行时间

# (4)调用pair setup中函数，用copy方式建立10 条流
# 参数方式：creatPairs_by_copy {pairCount  e1Addrs e2Addrs protocol script}
set pairs [creatPair_by_single $pairCount $e1Addrs $e2Addrs $tcp_protocol $High_Performance_Throughput_scipt]

# （5） 将pairs list 每个添加到test中
foreach pair $pairs {
    chrTest addPair $::test $pair
}

# (6) 调用test run函数进行测试, 测试时间是在前面设置test 属性中设置
chrRun $::test

#(7)# （8）等待测试结束检查测试是否已经完成,循环中可以加入获取results 来记录中间过程数据
# Wait for the test to stop.
# We'll check in a loop here every 5 seconds
# then call it an error after durtion + timeout minutes if
# the test is still not stopped.
log_to_file_info "Waiting for test finished"
set timer 0
set isStopped 0
puts "Waiting for the test to stop..."
while {!$isStopped && $timer < $maxWait} {

    set isStopped [chrTest isStopped $test $timeout]
    if {!$isStopped} {
        set timer [expr $timer + $timeout]
        log_to_file_info "Waiting for test to stop... ($timer)"
    }
}
if {!$isStopped} {
    # Show this as a timed out error
    set rc "CHRAPI 118"
    pLogError $test $rc "chrTest isStopped"
    return
}

#(9) 获取test 对象信息
displayTestInfo $::test
#(10) 获取test thp结果 并写入csv中
set results_to_csv [dispalyTestResluts $::test]
set sciptFileName [file rootname [file tail $argv0]
writeDataToCSV $sciptFileName $results_to_csv

