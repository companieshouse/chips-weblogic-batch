#!/bin/bash

# =============================================================================
#
#  This script is used to list JMS messages in a specific queue and repeat   
#  that operation on a number of WebLogic servers.
# 
#  This script expects one parameter:
#
#  QUEUE - the name of the queue to list JMS messages in, e.g. uk.gov.ch.chips.jms.EfilingRequestErrorQueue
#
#  In addition to the parameters, it also expects one or more environment
#  variables that list the connection details for the JMS Servers on which to 
#  perform the list operation. These variables must be called JMS_SERVER_URL_#
#  (where # is a unique identifier such as a number).  E.g.
#
#  JMS_SERVER_URL_1=t3s://chips-ef-batch0.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_2=t3s://chips-ef-batch1.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_3=t3s://chips-users-rest0.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_4=t3s://chips-users-rest1.heritage.aws.internal:21031|JMSServer1
#
# =============================================================================

cd /apps/oracle/admin/jms

# load variables created from setCron script
source /apps/oracle/env.variables

# set up logging
LOGS_DIR=../../logs/jms
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-list-all-jms-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec > >(tee "${LOG_FILE}") 2>&1

if [ "$#" -ne 1 ]
then
  f_logError "Invalid number of arguments - expected 1"
  f_logInfo "Usage: ./list-all-jms.sh <queue jndi name>"
  f_logInfo "Example: ./list-all-jms.sh uk.gov.ch.chips.jms.EfilingRequestErrorQueue"
  exit 1
fi

QUEUE=$1

JMS_SERVERS=$(env | sort | grep "^JMS_SERVER_URL_")
for JMS_SERVER in ${JMS_SERVERS};
do
  while IFS='|' read -r JMS_SERVER_URL JMS_SERVER_NAME;
  do
    f_logInfo "Processing ${JMS_SERVER} listing messages in ${QUEUE}"
    ./list-jms.sh ${JMS_SERVER_NAME}@${QUEUE} ${JMS_SERVER_URL} ${WEBLOGIC_ADMIN_USERNAME} ${ADMIN_PASSWORD}
  done < <(echo ${JMS_SERVER##*=})
done
