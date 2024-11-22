#!/bin/bash

## Script to compress log/image/data files created by batch jobs
##

# load variables created from setCron script
source /apps/oracle/env.variables

# set up logging
LOGS_DIR=/apps/oracle/logs/admin
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-compress-batch-files-$(date +'%Y-%m-%d').log"
source /apps/oracle/scripts/logging_functions

exec > ${LOG_FILE} 2>&1


f_logInfo  "~~~~~~~~ Starting Housekeeping of Files $(date) ~~~~~~~~~~~"
f_logInfo  "Running "$0

# Extract the JSON array using jq
json_array=$(jq -c '.compressfiles[]' /apps/oracle/config/admin-compressfiles.json)

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
f_logInfo  "These files will be compressed"
find ${DIRS} \( -name $pattern \) -mtime +${DAYS} -ls

f_logInfo  "Now compressing these files"
find ${DIRS} \( -name $pattern \) -mtime +${DAYS} -exec gzip {} \;

done
f_logInfo  "~~~~~~~~ Ending Housekeeping of Files ~~~~~~~~~~~"