#***************************************************************
#get the yaml data and logger
#***************************************************************
# Source the file containing the logger setup function
source "../Config/bytcl_logger_setup.tcl"
source "../Config/bytcl_yaml_setup.tcl"
source "../Config/bytcl_filePath_setup.tcl"


set file_yaml_name "chariot_set.yml"
set file_yaml_path [file join $Yaml_Path $file_yaml_name]
log_to_file_info "The yaml file path is: $file_yaml_path"
set yaml_data_dict [get_yaml_data $file_yaml_path]
log_to_file_info $yaml_data_dict
#***************************************************************
# Data for test:
# Change these values for your network if desired.
#***************************************************************
set appGroups [dict get $yaml_data_dict chariot_set appGroups]
set appGroup1 [lindex $appGroups 0]
set appGroup2 [lindex $appGroups 1]
set appGroup3 [lindex $appGroups 2]
log_to_file_info $appGroups
log_to_file_info $appGroup1
log_to_file_info $appGroup2
log_to_file_info $appGroup3


#*****************************************************************************************************************
# 这个函数根据提供的appGroup Name List 创建appGroup list
# 这个函数现在会在循环中创建多个aPPGroup 返回Gorup list
#*****************************************************************************************************************
porc creatAppGroup_by_list { appGroup_name_list } {
    set appGroups {}
    if {[string match {{*}} $appGroup_name_list]} {
        # 字符串被花括号包围，可能是一个列表
        set appGroupList [eval $appGroup_name_list]

        if {[llength $appGroupList] > 1} {
            log_to_file_info "appGroup_name_list is a list with multiple elements."
            foreach group_element $appGroupList {
                log_to_file_info "group_element: $group_element"
                set appGroupNew [chrAppGroup new]
                chrAppGroup set $appGroupNew APP_GROUP_NAME $group_element
                lappend appGroups $appGroupNew
                return $appGroups
            }
        } else {
            log_to_file_info "appGroup_name_list is a list with a single element."
            log_to_file_info "Element: $appGroupList"
            set appGroupNew [chrAppGroup new]
            chrAppGroup set $appGroupNew APP_GROUP_NAME $appGroupList
            return $appGroupNew
        }
    } else {
        # 字符串没有被花括号包围，可能是一个单独的元素
        log_to_file_info "appGroup_name_list is a single element or a string."
        log_to_file_info "Element: $appGroup_name"
        set appGroupNew [chrAppGroup new]
        chrAppGroup set $appGroupNew APP_GROUP_NAME $appGroupList
        return $appGroupNew
    }

}
#*****************************************************************************************************************
# 这个函数根据提供的appGroup Name  Group
# 这个函数创建一个Group 并返回
#*****************************************************************************************************************
porc creatAppGroup_by_name { appGroup_name } {
    log_to_file_info "Creat one Group"
    set appGroupNew [chrAppGroup new]
    charAppGroup set $appGroupNew APP_GROUP_NAME $appGroup_name
    return $appGroupNew

}