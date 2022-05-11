#!/bin/bash

# =============================================================================
#
#  This script is used to move JMS messages from one queue to another and repeat   
#  that operation on a number of WebLogic servers.
# 
#  This script expects three parameters:
#
#  SOURCE QUEUE - the name of the queue to move messages from, e.g. uk.gov.ch.chips.jms.EfilingRequestErrorQueue
#  DESTINATION QUEUE - the name of the queue to move messages to, e.g. uk.gov.ch.chips.jms.EfilingRequestQueue
#  NUMBER OF MESSAGES - the number of messages to move, e.g. 500 
#
#  In addition to the parameters, it also expects one or more environment
#  variables that list the connection details for the JMS Servers on which to 
#  perform the move operation. These variables must be called JMS_SERVER_URL_#
#  (where # is a unique idetifier such as a number).  E.g.
#
#  JMS_SERVER_URL_1=t3s://chips-ef-batch0.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_2=t3s://chips-ef-batch1.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_3=t3s://chips-users-rest0.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_4=t3s://chips-users-rest1.heritage.aws.internal:21031|JMSServer1
#
#  This script is intended to be called directly - either manually or via the cron.
#  
# =============================================================================

cd /apps/oracle/admin/jms

# load variables created from setCron script
source /apps/oracle/env.variables

# set up logging
LOGS_DIR=../../logs/jms
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-reprocess-jms-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec > >(tee "${LOG_FILE}") 2>&1

if [ "$#" -ne 3 ]
then
  f_logError "Invalid number of arguments - expected 3"
  f_logInfo "Usage: ./reprocess-jms.sh <source queue jndi name> <destination queue jndi name> <number of messages>"
  f_logInfo "Example: ./reprocess-jms.sh uk.gov.ch.chips.jms.EfilingRequestErrorQueue uk.gov.ch.chips.jms.EfilingRequestQueue 500"
  exit 1
fi

SOURCE_QUEUE=$1
DESTINATION_QUEUE=$2
NUMBER_OF_MESSAGES=$3

JMS_SERVERS=$(env | sort | grep "^JMS_SERVER_URL_")
for JMS_SERVER in ${JMS_SERVERS};
do
  while IFS='|' read -r JMS_SERVER_URL JMS_SERVER_NAME;
  do
    f_logInfo "Processing ${JMS_SERVER} moving messages from ${SOURCE_QUEUE} to ${DESTINATION_QUEUE}"
    ./move-jms.sh ${JMS_SERVER_NAME}@${SOURCE_QUEUE} ${JMS_SERVER_NAME}@${DESTINATION_QUEUE} ${JMS_SERVER_URL} ${WEBLOGIC_ADMIN_USERNAME} ${ADMIN_PASSWORD} ${NUMBER_OF_MESSAGES}
    if [ $? -gt 0 ]; then
      f_logError "Non-zero exit code for move-jms execution"
    fi
  done < <(echo ${JMS_SERVER##*=})
done
