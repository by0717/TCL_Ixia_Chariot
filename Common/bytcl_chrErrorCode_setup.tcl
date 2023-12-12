source "../Config/bytcl_logger_setup.tcl"
source "../Common/bytcl_chrTest_setup.tcl"

#***************************************************************
# Procedure to log errors if there is extended info
#***************************************************************
proc pLogError {handle code where} {
    # Define symbols for the errors we're interested in.
    set CHR_OPERATION_FAILED "CHRAPI 108"
    set CHR_OBJECT_INVALID   "CHRAPI 112"
    set CHR_NO_SUCH_VALUE   "CHRAPI 116"
    set CHR_APP_GROUP_INVALID "CHRAPI 136"

    # Something failed: show what happened.
    log_to_file_info "$where failed: [chrApi getReturnMsg $code]"

    # See if there is extended error information available.
    # It's is only meaningful for certain errors.
    if {$code == $CHR_OPERATION_FAILED ||
        $code == $CHR_OBJECT_INVALID ||
        $code == $CHR_NO_SUCH_VALUE ||
        $code == $CHR_APP_GROUP_INVALID} {

        # Try to get the extended error information
        set rc [catch {set info [chrCommonError getInfo \
            $handle "ALL"]}]
            if {$rc != 0} {

            # We can ignore all non-success return codes here
            # because most should not occur (the api's been
            # initialized and the detail level is okay),
            # and the NO_SUCH_VALUE return code here means
            # there is no info available.
            set info "<None>"
        }
        # set logFile [open $logFile a+]
        # set timestamp [clock format [clock seconds]]
        log_info_file_info: "$where failed"
        log_info_file_info "$info"
        # Flush forces immediate write to file
        # flush $logFile
    }
}