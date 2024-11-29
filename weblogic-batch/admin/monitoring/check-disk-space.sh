#!/bin/bash

## Script to check the disk space based on configure paths and will send alerts  
##

# load variables created from setCron script
source /apps/oracle/env.variables

#  Load alerting functions
source /apps/oracle/scripts/alert_functions

# set up logging
LOGS_DIR=/apps/oracle/logs/admin
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-check-disk-space.log"
source /apps/oracle/scripts/logging_functions
#set -xv
exec > ${LOG_FILE} 2>&1


f_logInfo  "~~~~~~~~ Starting Checking Disk Space  ~~~~~~~~~~~"
f_logInfo  "Running $0 with process $$"

f_logInfo "OLTP_CHECK_DISK_SPACE_PATHS : $OLTP_CHECK_DISK_SPACE_PATHS"


for path in $OLTP_CHECK_DISK_SPACE_PATHS; do
f_logInfo  "Checking disk space for path... $path"  
DISK_SPACE_USAGE=`df -Pk | grep "$path" | awk '{print $5}' | sort -n | tail -1 | sed 's/%//g'`

if [ ${DISK_SPACE_USAGE} -ge ${OLTP_CHECK_DISK_SPACE_THRESHOLD} ]; then
    MSG="High disk usage for the path $path with $DISK_SPACE_USAGE percentage"
    f_logWarn "$MSG"
    email_CHAPS_group_f "${ENVIRONMENT_LABEL} $PROGNAME High disk usage on ${HOSTNAME}" "$MSG"
fi

done

f_logInfo  "~~~~~~~~ Ending Checking Disk Space ~~~~~~~~~~~"