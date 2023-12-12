# 设置项目根目录
set projectRoot [file dirname [file dirname [info script]]]
# puts $projectRoot
# 返回指定文件的路径
proc getFilePath {dirName} {
    global projectRoot
    return [file join $projectRoot $dirName]
}


set CSV_Path [getFilePath "CSV" ]
set Config_Path [getFilePath "Config"]
set Case_Path [getFilePath "Case"]
set Common_Path [getFilePath "Common"]
set Yaml_Path [getFilePath "Yaml"]
set LogFile_Path [getFilePath "Logs"]
set tstSave_Path [getFilePath "Tst"]
# puts $LogFile_Path
# puts $Yaml_Path