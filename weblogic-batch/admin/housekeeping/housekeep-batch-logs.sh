#!/bin/bash

## Script to prune log files created by chips-weblogic-batch jobs
## $1 is days to keep 
## we will only log latest run, no need to have this log loads 
##

if [[ $# -eq 0 ]] ; then
    echo 'Logs will be deleted if older than the days you supply as script argument '
    echo 'Example: /apps/oracle/admin/housekeeping/housekeep-batch-logs.sh 90'
    exit 1
fi

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

# set up logging
LOGS_DIR=/apps/oracle/logs/admin
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-housekeep-batch-logs.log"
source /apps/oracle/scripts/logging_functions

exec > ${LOG_FILE} 2>&1

## go to root of logs directory
cd /apps/oracle/logs

## hard coded list of Batch directories as this is in a shared mount point so we are specific
DIRS="compliance-trigger doc1-producer letter-producer process-compliance batchmanager cron image-regeneration mid-to-chs psc-pursuit-trigger bulk-image-load dissolution-certificate-producer eaidaemon jms officer-bulk-process ssodaemon"

## Logs will be deleted if older than the days you supply as script argument 
DAYS=$1

f_logInfo  "~~~~~~~~ Starting Housekeeping of Log Files $(date) ~~~~~~~~~~~"
f_logInfo  "Running "$0

f_logInfo  "These files will be removed"
find ${DIRS} \( -name "*log" \) -mtime +${DAYS} -ls

f_logInfo  "Now removing these files"
find ${DIRS} \( -name "*log" \) -mtime +${DAYS} -exec rm {} \;

f_logInfo  "~~~~~~~~ Ending Housekeeping of Log Files ~~~~~~~~~~~"

