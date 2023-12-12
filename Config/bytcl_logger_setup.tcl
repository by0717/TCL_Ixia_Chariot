# Logging to a simple file
#
# This creates the file mylog.log and adds a single line.
#
# (c) 2005 Michael Schlenker <mic42@users.sourceforge.net>
#
# $Id: logtofile.tcl,v 1.2 2005/09/28 03:46:37 andreas_kupries Exp $
#
#
lappend auto_path "D:/ActiveTcl/lib/tcllib1.21"
package require logger
# source "../Config/bytcl_yaml_setup.tcl"
source "../Config/bytcl_filePath_setup.tcl"
#***************************************************************
# set file_yaml_name "chariot_set.yml"
# set file_yaml_path [file join $Yaml_Path $file_yaml_name]
# set yaml_data_dict [get_yaml_data $file_yaml_path]
#***************************************************************
# Define a procedure to initialize the logger and set up log levels
proc initialize_logger {} {
    # 自定义日志处理程序
    proc log_to_file {lvl txt} {
        set log_time [clock format [clock seconds] -format "%Y-%m-%d_%H-%M-%S"]
        set logName "tcl_log_$log_time.log"
        set logfile [file join  $::LogFile_Path $logName]

        set msg "\[[clock format [clock seconds] -format "%H:%M:%S"]\] $lvl: $txt"

        set f [open $logfile {RDWR CREAT APPEND}]
        fconfigure $f -encoding utf-8
        puts $f $msg
        close $f
    }

    # 初始化日志器
    set log [logger::init global]

    # 为所有级别安装日志处理程序
    foreach lvl [logger::levels] {
        interp alias {} log_to_file_$lvl {} log_to_file $lvl
        ${log}::logproc $lvl log_to_file_$lvl
    }
}

# 调用初始化函数
initialize_logger
