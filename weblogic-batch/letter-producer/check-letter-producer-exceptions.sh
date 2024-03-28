#!/bin/bash
######################################################################################
# check-letter-producer-exceptions.sh                                                    #
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
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-check-letter-producer-exceptions.log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting check-letter-producer-exceptions"

WLS_LOG="/apps/oracle/logs/wlserver1/logs/wlserver1.out"
RESULT=$(grep 'uk.gov.ch.chips.server.letterproducer.ElectronicCommunicationsDaoImpl.synchronise' ${WLS_LOG})

if [[ -n $RESULT ]];then
  ## All good, JMS message recieved for today
  f_logInfo " There are no significat issues : $RESULT"
  exit 0
else
  ## MDB not recieved which means Letters are not processing
  f_logError "Letter Producer has failed to update the ecom table due to timeout!!!"
  email_CHAPS_group_f "Letter Producer has failed to update the ecom table due to timeout" "Letter Producer has failed to update the ecom table due to timeout. Check process_compliance log and ${WLS_LOG}."
  exit 1
fi

