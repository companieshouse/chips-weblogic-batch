#!/bin/bash

cd /apps/oracle/letter-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst < ../.msmtprc.template > ../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/letter-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-check-letter-producer-2nd-phase-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting check-letter-producer-2nd-phase"

VAR=$(grep '2nd Phase Processing Statistics' ../logs/wlserver1/logs/wlserver1.out)

if [[ -n $VAR ]];then
 TIME=$(echo $VAR|awk '{print $6}')
 email_report_CHAPS_group_f "2nd Phase Letter processing completed at $TIME" "$VAR"
 f_logInfo "2nd Phase Letter processing completed at $TIME : $VAR"
 exit 0
fi

## If we got this far we haven't found string
f_logError "2nd Phase Letter processing NOT completed yet"
email_CHAPS_group_f "2nd Phase Letter processing NOT completed yet" "Please check 2nd Phase Letter run... there may be problems"
