#!/bin/bash
###########################
# Define script variables #
###########################
# Define the cluster name or IP
CLUSTER="10.193.67.10"
# Define the volume name if querying a specific volume 
VOLUME="lotsafiles"
# Define the SVM name
SVM="DEMO"
# Set the increase and threshold percent to use with the script
MAXFILE_PERCENT_INCREASE="5"
MAXFILE_THRESHOLD="80"
# Get auth token from system manager at https://cluster/docs/api/
AUTH_TOK="YWRtaW46bmV0YXBwMSE="

## Find max files and files used for all volumes
#curl -X GET "https://$CLUSTER/api/storage/volumes?fields=files&return_records=true&return_timeout=15" -k -H "accept: application/json" -H "authorization: Basic $AUTH_TOK"

## Find max files and files used for all volumes in a specific SVM
#curl -X GET "https://$CLUSTER/api/storage/volumes?svm.name=$SVM&fields=files&return_records=true&return_timeout=15" -k -H "accept: application/json" -H "authorization: Basic $AUTH_TOK"

## Find max files and files used for a specific volume name and SVM
curl -X GET "https://$CLUSTER/api/storage/volumes?name=$VOLUME&svm.name=$SVM&fields=files,uuid&return_records=true&return_timeout=15" -H "accept: application/json" -k -H "authorization: Basic $AUTH_TOK" > files_output.log

## Collect files and used files values and calculate the percent used
TOTAL_FILES=$(cat files_output.log | grep max | sed 's/[^0-9]*//g')
USED_FILES=$(cat files_output.log | grep used | sed 's/[^0-9]*//g')
## Get vol UUID
cat files_output.log | grep uuid | sed 's/uuid//g;s/[":, ]//g' > uuid.txt
VOL_UUID=$(cat uuid.txt)

# Output results
echo =================================================
echo "|$TOTAL_FILES| total inodes for volume \"$VOLUME\""
echo "|$USED_FILES| inodes used for volume \"$VOLUME\""
PERCENT_USED=$((100*$USED_FILES/$TOTAL_FILES))
echo $PERCENT_USED"% inodes used for volume \"$VOLUME\""
echo =================================================
echo "Volume UUID of \"$VOLUME\" is $VOL_UUID"

# If/then statement that measures percent of inodes used (PERCENT_USED) and increases by a value (MAXFILE_PERCENT_INCREASE)
if [ "$PERCENT_USED" -gt "$MAXFILE_THRESHOLD" ] ; then
        ## If % exceeds an amount, run script to increase maxfiles by an amount (ie, if we hit 80% files used, increase maxfiles by 10%)
        FILE_INCREMENT=$(($TOTAL_FILES*$MAXFILE_PERCENT_INCREASE/100))
        echo "Total inodes will be increased by >>>$FILE_INCREMENT<<<"
        echo
        MAXFILE_INCREASE=$(($FILE_INCREMENT+$TOTAL_FILES))
        echo "New maxfiles value will be: >>>$MAXFILE_INCREASE<<<"

        # REST API to set maxfiles to a higher value; uses variables set in the script above to figure out maxfile increase
        curl -X PATCH "https://$CLUSTER/api/storage/volumes/$VOL_UUID?sizing_method=use_existing_resources&return_timeout=0" -H "accept: application/json" -H "authorization: Basic $AUTH_TOK" -k -H "Content-Type: application/json" -d "{ \"files\": { \"maximum\": $MAXFILE_INCREASE }}"
else
        echo ===========================================
        echo "No inode increase needed at this time; files used threshold is below $MAXFILE_THRESHOLD%"
        echo ===========================================
fi
