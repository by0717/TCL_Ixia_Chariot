##***************************************************************
# Barry Chariot TCl scipt
# This scipt use to record log
# This scipt use to read yaml config of chariot
#***************************************************************
#
# set scriptDir [file normalize [file dirname $argv0]]
# set yaml_file_name "chariot_set.yml"
# set yaml_filePath [file join $scriptDir $yaml_file_name]
# puts $yaml_filePath
# set yamlData [yaml::yaml2dict -file $yaml_filePath]
# puts "Yaml Data: \n"
# puts $yamlData
# puts "hpth_script_file: [dict get $yamlData chariot_set hpth_script_file]"
#***************************************************************
lappend auto_path "D:/ActiveTcl/lib/tcllib1.21"
package require yaml


proc get_yamlfile_path {yaml_file_name} {
    set scriptDir [file normalize [file dirname [info script]]]
    set yaml_filePath [file join $scriptDir $yaml_file_name]
    puts $yaml_filePath
    return $yaml_filePath
}


proc get_yaml_data {yaml_file_path} {
    set yaml_data [yaml::yaml2dict -file $yaml_file_path]
    return $yaml_data
}
