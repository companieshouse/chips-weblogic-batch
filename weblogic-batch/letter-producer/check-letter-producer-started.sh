#!/bin/bash
######################################################################################
# check-letter-producer-started.sh                                                    #
# Script to check JMS arrived on manages server and letterproducer has started        #
# Alert On Call if string 'Start of LetterProducerMDB' is not in logs by certain time #
# If alerted, possible Admin server failure to send MDB to managed server wlserver1   #
######################################################################################
cd /apps/oracle/letter-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst < ../.msmtprc.template > ../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=$HOME/logs/letter-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-check-letter-producer-started.log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting check-letter-producer-started"

WLS_LOG="/apps/oracle/logs/wlserver1/logs/wlserver1.out"
RESULT=$(grep 'Start of LetterProducerMDB' ${WLS_LOG})

if [[ -n $RESULT ]];then
  ## All good, JMS message recieved for today
  f_logInfo " LetterProducerMDB recieved : $RESULT"
  exit 0
else
  ## MDB not recieved which means Letters are not processing
  f_logError "LetterProducerMDB NOT received. Probable error with Admin server or Managed Server !!!"
  email_CHAPS_group_f "LetterProducerMDB has not started in process-compliance" "LetterProducerMDB NOT recieved which means Letters are not processing. Check process_compliance log and ${WLS_LOG}."
  patrol_log_alert_chaps_f " `pwd`/`basename $0`: LetterProducerMDB has not started in process-compliance which means Letters are not processing. "
  exit 1
fi

