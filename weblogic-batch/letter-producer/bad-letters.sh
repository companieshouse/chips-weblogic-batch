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
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-bad-letters-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting bad-letters"

cd /apps/oracle/input-output/letterProducerOutput

find . -name '*.xml' -type f -print | grep -v large_font | grep -v schedule |  grep -v DissCerts | grep '_'>/tmp/bad_letters

cut -c30-39 /tmp/bad_letters>/tmp/bad_letter_id

cat /tmp/bad_letter_id

email_report_CHAPS_group_f "Weekly Bad Letter Ids" "`cat /tmp/bad_letter_id`"

f_logInfo "Ending bad-letters"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"