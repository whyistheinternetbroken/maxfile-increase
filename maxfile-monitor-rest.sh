#!/bin/bash
# README
# * This script can be run as a cron job. Interval of monitoring depends on how fast files are created.
#
# * Script can be customized with monitoring threshold (percent of used inodes) and what percentage to increase inode count by.
#
# * Inode increase percentage should generally be in 5-10% increments, but can be more if file churn is greater.
#
# * Once max inodes are increased, they cannot be decreased.
#
# * Auth tokens can be generated using the System Manager "try it out" button on the API docs page. This can be found at https://cluster-ip/docs/api/
#
# * If/when multiple volumes need to be monitored, use multiple instances of this script.
#
# * Three text files get created:
#    - "uuid.txt" captures the volume UUID that is used for increasing the max inodes; this gets overwritten
#    - "files_monitor.log" keeps a rolling tally of the date/timestamps of the script and the files/files-used/percent used/incremental increases.
#    - "files_output.log" collects the REST API output from the cluster
#
# * The LOG_PATH variable allows you to define the output file locations.
#
#
#
###########################
# Define script variables #
###########################

# Define the cluster name or management IP
CLUSTER="x.x.x.x"

# Define the volume name
VOLUME="VOLNAME"

# Define the SVM name
SVM="SVM-NAME"

# Set the increase and threshold percent to use with the script
MAXFILE_PERCENT_INCREASE="5"
MAXFILE_THRESHOLD="80"

# Set authorization token for REST calls
AUTH_TOK="YWRtaW46TjAkMHVwNFUhIQ=="

# Specify the log file/input file paths. Use . for same directory as where you ran the script.
LOG_PATH="."

###########################
#       Functions         #
###########################
# Function to print a line of - characters
print_separator() {
    local num_chars=$1
    for ((i=0; i<num_chars; i++)); do
        printf '='
    done
    echo
}

# Function to print a line of - characters
print_dash_separator() {
    local num_chars=$1
    for ((i=0; i<num_chars; i++)); do
        printf '-'
    done
    echo
}

# Timestamps
time_stamp_start()
{
    echo "Script started at: $(date)"
}

time_stamp_end()
{
    echo "Script finished at: $(date)"
}


# Parse inode count
parse_inodes()
{
    ## Collect files and used files values and calculate the percent used
    TOTAL_FILES=$(grep max files_output.log | sed 's/[^0-9]*//g')
    USED_FILES=$(grep used files_output.log | sed 's/[^0-9]*//g')
    ## Get vol UUID
    grep uuid files_output.log | sed 's/uuid//g;s/[":, ]//g' > uuid.txt
    VOL_UUID=$(cat uuid.txt)
}

# Monitor files
monitor_files()
{
    PERCENT_USED=$((100 * USED_FILES / TOTAL_FILES))
    echo "ONTAP VOLUME MAXFILES INFORMATION"
    print_dash_separator 103
    # Print the header
    printf "| %-12s | %-36s | %-11s | %-16s | %-12s |\n" "Volume Name" "Volume UUID" "Total files" "Total files used" "% Files used"
    print_dash_separator 103
    # Print the values
    printf "| %-12s | %-36s | %-11d | %-16d | %-12d |\n" "$VOLUME" "$VOL_UUID" "$TOTAL_FILES" "$USED_FILES" "$PERCENT_USED"
    print_dash_separator 103
    echo
    if ! [[ "$MAXFILE_PERCENT_INCREASE" =~ ^[0-9]+$ ]] || [ "$MAXFILE_PERCENT_INCREASE" -lt 1 ] || [ "$MAXFILE_PERCENT_INCREASE" -gt 100 ]; then
        echo "Error: MAXFILE_PERCENT_INCREASE variable must be a number between 1 and 100. Change variable in script and retry."
        exit 1
    fi
    if [ "$PERCENT_USED" -gt "$MAXFILE_THRESHOLD" ]; then
        echo "********************************************WARNING********************************************"
        echo " $PERCENT_USED% inodes used for volume \"$VOLUME\" is greater than the configured maxfile threshold of $MAXFILE_THRESHOLD%."
        echo "***********************************************************************************************"
        echo
        echo "Maxfiles value for the volume will be increased by $MAXFILE_PERCENT_INCREASE%."
        echo
        sleep 5
    else
        echo "**** $PERCENT_USED% inodes used for volume \"$VOLUME\" - Within normal threshold of $MAXFILE_THRESHOLD%. ****"
        echo
    fi
}

# Calculate increase
calculate_increase()
{
    ## If % exceeds an amount, run script to increase maxfiles by an amount (ie, if we hit 80% files used, increase maxfiles by 10%)
    FILE_INCREMENT=$((TOTAL_FILES * MAXFILE_PERCENT_INCREASE / 100))
    MAXFILE_INCREASE=$((FILE_INCREMENT + TOTAL_FILES))
    INCREASE_TABLE=$(printf "| %-31s | %12d |\n" "Total inodes increased by" "$FILE_INCREMENT" \
                    && printf "| %-31s | %12d |\n" "New maxfiles value for volume" "$MAXFILE_INCREASE" \
                    && printf "| %-31s | %12s |\n" "Percent increase" "$MAXFILE_PERCENT_INCREASE%")
}

# Increase files
# REST API to set maxfiles to a higher value; uses variables set in the script above to figure out maxfile increase
increase_files()
{
    curl -X PATCH "https://$CLUSTER/api/storage/volumes/$VOL_UUID?sizing_method=use_existing_resources&return_timeout=0" \
        -H "accept: application/json" \
        -H "authorization: Basic $AUTH_TOK" \
        -k \
        -H "Content-Type: application/json" \
        -d "{ \"files\": { \"maximum\": $MAXFILE_INCREASE }}" -o /dev/null 2> "$LOG_PATH/curl_perf.txt" || {
        echo "Error: Failed to increase maxfiles."
        exit 1
    }
}

###########################
#       END Functions     #
###########################

## Find max files and files used for a specific volume name and SVM
echo "Fetching volume maxfiles information..."
echo
curl -X GET "https://$CLUSTER/api/storage/volumes?name=$VOLUME&svm.name=$SVM&fields=files,uuid&return_records=true&return_timeout=15" \
    -H "accept: application/json" \
    -k \
    -H "authorization: Basic $AUTH_TOK" > "$LOG_PATH/files_output.log" || {
    echo "Error: Failed to retrieve volume information."
    exit 1
}

## Run job
echo
print_separator 100
echo
print_dash_separator 50
time_stamp_start
print_dash_separator 50
echo
parse_inodes

# Output results
monitor_files

# If/then statement that measures percent of inodes used (PERCENT_USED) and increases by a value (MAXFILE_PERCENT_INCREASE)
if [ "$PERCENT_USED" -gt "$MAXFILE_THRESHOLD" ]; then
    calculate_increase
    increase_files

    # Re-run to get the latest information
    echo "Fetching updated volume maxfiles information..."
    echo
    curl -X GET "https://$CLUSTER/api/storage/volumes?name=$VOLUME&svm.name=$SVM&fields=files,uuid&return_records=true&return_timeout=15" \
        -H "accept: application/json" \
        -k \
        -H "authorization: Basic $AUTH_TOK" > "$LOG_PATH/files_output.log" || {
        echo "Error: Failed to retrieve volume information."
        exit 1
    }
    parse_inodes
    echo
    print_dash_separator 50
    echo "$INCREASE_TABLE"
    print_dash_separator 50

    # Recalculate the percentage used with the new maxfiles
    PERCENT_USED=$((100 * USED_FILES / TOTAL_FILES))

    echo
    echo "NEW ONTAP VOLUME MAXFILES INFORMATION"
    print_dash_separator 103
    # Print the header
    printf "| %-12s | %-36s | %-11s | %-16s | %-12s |\n" "Volume Name" "Volume UUID" "Total files" "Total files used" "% Files used"
    print_dash_separator 103
    # Print the values
    printf "| %-12s | %-36s | %-11d | %-16d | %-12d |\n" "$VOLUME" "$VOL_UUID" "$TOTAL_FILES" "$USED_FILES" "$PERCENT_USED"
    print_dash_separator 103
    echo
fi
echo
print_dash_separator 50
time_stamp_end
print_dash_separator 50
echo
echo "Done!"
echo
print_separator 100
