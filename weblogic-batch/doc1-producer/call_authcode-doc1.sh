#!/bin/bash

#Script to call authcode-doc1.sh

cd /apps/oracle/doc1-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

# Setting up standard logging here
# set up logging
LOGS_DIR=../logs/doc1-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-authcode-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> "${LOG_FILE}" 2>&1

# Initialise variables
hour=`date +'%H'`

AUTHCODE_SOURCE="/apps/oracle/input-output/authcodeInput"

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

while [ $hour -gt 03 ] && [ $hour -lt 11 ]
do
FILECOUNT=`ls -1 ${AUTHCODE_SOURCE}/AUTHCODE.txt | wc -l`

if [ 0 -eq ${FILECOUNT} ] ; then
  f_logInfo "No AuthCode file found to process yet. Sleeping 30s"
  sleep 30
else
  f_logInfo "AuthCode File found. Starting AuthCode process."
  ./authcode-doc1.sh
  exit 0
fi
done
# if we get this far, file still not available so job not run
f_logError "No AuthCode file found to process - job not run."
email_CHAPS_group_f " $(pwd)/$(basename $0): No AuthCode file found to process - job not run."
exit 1