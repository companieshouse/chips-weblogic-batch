#!/bin/bash

## Script to move log/image/data files onto S3 created by batch jobs 
##

# load variables created from setCron script
source /apps/oracle/env.variables

# set up logging
LOGS_DIR=/apps/oracle/logs/admin
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-archive-files-on-s3-$(date +'%Y-%m-%d').log"
source /apps/oracle/scripts/logging_functions

exec > ${LOG_FILE} 2>&1


f_logInfo  "~~~~~~~~ Starting Housekeeping of Files $(date) ~~~~~~~~~~~"
f_logInfo  "Running "$0

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

f_logInfo  "Now compressing these files"
for file in "$(find ${DIRS} \( -name $pattern \) -mtime +${DAYS} -ls)"; do
 f_logInfo  "Uploading to S3... $file"  
if aws s3api put-object --bucket "${ARCHIVE_S3_BUCKET}" --body "${file}" --key "$file" --profile ${ARCHIVE_S3_PROFILE} --server-side-encryption aws:kms --ssekms-key-id ${ARCHIVE_S3_KMS}; then
       f_logInfo  "Uploaded onto S3... $file" 
       if aws s3 ls "$ARCHIVE_S3_BUCKET/$file" > /dev/null 2>&1; then
        f_logInfo "File already exists on S3. Now it's safe to remove the files."
        rm ${file}
       else
        f_logWarn "File does not exist on S3. Please investigate."
       fi
      else
       f_logError "Copying to file onto S3 has filed."
      fi

done
f_logInfo  "~~~~~~~~ Ending Housekeeping of Files ~~~~~~~~~~~"