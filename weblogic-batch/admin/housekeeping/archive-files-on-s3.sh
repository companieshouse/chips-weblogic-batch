#!/bin/bash

## Script to move log/image/data files onto S3 created by batch jobs 
##

# load variables created from setCron script
source /apps/oracle/env.variables

#  Load alerting functions
source /apps/oracle/scripts/alert_functions

# set up logging
LOGS_DIR=/apps/oracle/logs/admin
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-archive-files-on-s3-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions
#set -xv
exec > ${LOG_FILE} 2>&1

# Set up pid file directory
LOCKS_DIR=/apps/oracle/locks/archive-files-on-s3
mkdir -p ${LOCKS_DIR}

f_logInfo  "~~~~~~~~ Starting Housekeeping of Files  ~~~~~~~~~~~"
f_logInfo  "Running $0 with process $$"

# =============================================================================
# remove lock file
# =============================================================================
remove_lock() {

[ -f ${LOCKS_DIR}/.archive-files-on-s3.pid ] && rm ${LOCKS_DIR}/.archive-files-on-s3.pid

}

# =============================================================================
# set pid lock file
# =============================================================================

if [ -f ${LOCKS_DIR}/.archive-files-on-s3.pid ]
then
  PS_ID=`cat ${LOCKS_DIR}/.archive-files-on-s3.pid`
  MSG="already running as process ${PS_ID}. or previous run failed"
  f_logError "$MSG"
  #email_report_f "${EMAIL_ADDRESS_CSI}" "${ENVIRONMENT_LABEL} $PROGNAME Lock File Exists" "$MSG"
  email_CHAPS_group_f "${ENVIRONMENT_LABEL} $PROGNAME Lock File Exists" "$MSG"
  exit 1
fi

echo $$ > ${LOCKS_DIR}/.archive-files-on-s3.pid

FAILURE_ALERT_FLAG_FILE="$LOGS_DIR/archive-files-on-s3-failure.flag"

# Extract the JSON array using jq
json_array=$(jq -c '.archivefiles[]' /apps/oracle/config/admin-archive-files-on-s3.json)

f_logInfo "data is $json_array"

# Loop through the JSON array
for item in $json_array; do
  f_logInfo "item is $item"

  # Access individual elements within the loop
  pattern=$(echo "$item" | jq -r '.pattern')
  days=$(echo "$item" | jq -r '.days')
  rootDir=$(echo "$item" | jq -r '.rootDir')
  dirs=$(echo "$item" | jq -r '.dirs')


  # Perform actions on each element
  f_logInfo "pattern: $pattern"
  f_logInfo "days: $days"
  f_logInfo "rootDir: $rootDir"
  f_logInfo "dirs: $dirs"

## go to root of directory
cd $rootDir
## Logs will be deleted if older than the days you supply as script argument
DAYS=$days

## get the list of log directories from json as this is in a shared mount point so we are specific
DIRS=$(echo "$dirs" | tr ',' ' ')

f_logInfo  "DIRS are $DIRS"
f_logInfo  "These files will be moved to S3"
find ${DIRS} \( -name $pattern \) -mtime +${DAYS} -ls

if [ -f ${FAILURE_ALERT_FLAG_FILE} ]
   then
    rm $FAILURE_ALERT_FLAG_FILE
fi

f_logInfo  "Now moving these files to S3"
for file in $(find ${DIRS} \( -name $pattern \) -mtime +${DAYS}); do
file=$(realpath $file)
 f_logInfo  "Uploading to S3... $file"  
 key="${file#/}"
    if aws s3api put-object --bucket "${ARCHIVE_S3_BUCKET}" --profile ${ARCHIVE_S3_PROFILE} --body "${file}" --key "$key" --server-side-encryption aws:kms --ssekms-key-id ${ARCHIVE_S3_KMS}; then
        f_logInfo  "Uploaded onto S3... $file. Now file is being removed from local file system" 
        rm ${file}
    else
        f_logError "Copying to file onto S3 has filed $file."
        if [ -f ${FAILURE_ALERT_FLAG_FILE} ]
        then
            f_logInfo "No alert as flag file already present"
        else 
            touch $FAILURE_ALERT_FLAG_FILE
            email_CHAPS_group_f "${ENVIRONMENT_LABEL} $PROGNAME Copying to S3 has failed" "Copying to file onto S3 has filed, please check the logs $LOG_FILE"
        fi
    fi
done

done

remove_lock

f_logInfo  "~~~~~~~~ Ending Housekeeping of Files ~~~~~~~~~~~"