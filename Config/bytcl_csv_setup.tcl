# csv_utils.tcl

# Package require csv
lappend auto_path "D:/ActiveTcl/lib/tcllib1.21"
package require csv
source "../Config/bytcl_filePath_setup.tcl"

# Function to write data to a CSV file
proc writeDataToCSV {fileName data} {
    set filePath [file join $::CSV_Path $fileName]

    # Open the CSV file in "write" mode
    set csvFile [open $filePath "a"]

    # Write data to the CSV file
    if {[llength [lindex $data 0]] > 1} {
        # Data is a list of lists, use ::csv::joinlist
        set csv_data [::csv::joinlist $data]
    } else {
        # Data is a single list, use ::csv::join
        set csv_data [::csv::join $data]

    }
    puts $csvFile $csv_data
    close $csvFile ;# Close the CSV file

    return $filePath
}


# # Example usage with default values
# set singleListData {"Name" "Age" "City"}
# set multiListData {
#     {"Name" "Age" "City"}
#     {"John" 25 "New York"}
#     {"Alice" 30 "Los Angeles"}
# }

# set fileNameSingleList "example_data_single.csv"
# set fileNameMultiList "example_data_multi.csv"

# set resultPathSingleList [writeDataToCSV $fileNameSingleList $singleListData]
# set resultPathMultiList [writeDataToCSV $fileNameMultiList $multiListData]

# puts "Data has been written to: $resultPathSingleList"
# puts "Data has been written to: $resultPathMultiList"
