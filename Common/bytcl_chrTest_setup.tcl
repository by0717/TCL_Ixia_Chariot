source "../Config/bytcl_logger_setup.tcl"
source "../Config/bytcl_yaml_setup.tcl"
source "../Config/bytcl_"


#***************************************************************
set file_yaml_name "chariot_set.yml"
set file_yaml_path [file join $Yaml_Path $file_yaml_name]
log_to_file_info "The yaml file path is: $file_yaml_path"
set yaml_data_dict [get_yaml_data $file_yaml_path]
#***************************************************************
set chariotExt_path [dict get $yaml_data_dict chariot_set chariotExt_path]
log_to_file_info $chariotExt_path
#***************************************************************
load $chariotExt_path
package require ChariotExt
set ::test [chrTest new]
log_to_file_info "Creat new test success"


proc chrRun {test_handle} {
    log_to_file_info "Test Through start................................................."
    chrTest start $test_handle
}

proc chrStop {test_handle} {
    log_to_file_info "Test Throgh stop.................................................."
    chrTest stop $test_handle
}

proc chrIsStoped {test_handle timeout} {
    if {![chrTest isStopped $test_handle  $timeout]} {
        puts "ERROR: Test didn't stop in $timeout"
        chrTest delete $test_handle force
        return
    }
}

proc chrTstSave {test_handle} {
    if {[catch {chrTest save $test_handle}]} {
        pLogError $test_handle $errorCode "chrTest save"
    }
}