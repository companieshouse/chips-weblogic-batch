#!/bin/bash

# =============================================================================
#
#  This script is used to remove JMS messages from queue and repeat   
#  that operation on a number of WebLogic servers based on given JMS Message Id.
# 
#  This script expects three parameters:
#
#  SOURCE QUEUE - the name of the queue to move messages from, e.g. uk.gov.ch.chips.jms.EfilingRequestErrorQueue
#  NUMBER OF MESSAGES - the number of messages to move, e.g. 500 
#  Identifiers - the JMS Message Id of the messages to be removed, e.g. ID:61398.1770829232697.0
#  In addition to the parameters, it also expects one or more environment
#  variables that list the connection details for the JMS Servers on which to 
#  perform the move operation. These variables must be called JMS_SERVER_URL_#
#  (where # is a unique identifier such as a number).  E.g.
#
#  JMS_SERVER_URL_1=t3s://chips-ef-batch0.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_2=t3s://chips-ef-batch1.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_3=t3s://chips-users-rest0.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_4=t3s://chips-users-rest1.heritage.aws.internal:21031|JMSServer1
#
#  This script is intended to be called manually.
#  
# =============================================================================

cd /apps/oracle/admin/jms

# load variables created from setCron script
source /apps/oracle/env.variables

# set up logging
LOGS_DIR=../../logs/jms
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-remove-jms-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec > >(tee "${LOG_FILE}") 2>&1
if [ "$#" -ne 3 ]
then
  f_logError "Invalid number of arguments - expected 3"
  f_logInfo "Usage: ./remove-jms-messages.sh.sh <source queue jndi name> <he JMS Message Id of the messages to be removed> <number of messages>"
  f_logInfo "Example: ./remove-jms-messages.sh.sh uk.gov.ch.chips.jms.EfilingRequestErrorQueue 61398.1770829232697.0|61398.1770829232697.2 500"
  exit 1
fi

SOURCE_QUEUE=$1
IDENTIFIERS="$2"
NUMBER_OF_MESSAGES=$3

LIBS=/apps/oracle/libs
CLASSPATH=${LIBS}/jmstool.jar:${LIBS}/log4j-1.2-api.jar:${LIBS}/log4j-api.jar:${LIBS}/log4j-core.jar:${LIBS}/jms-api.jar:${LIBS}/wlthint3client.jar:${LIBS}/jdom.jar:${LIBS}/chips-common.jar:${LIBS}/com.bea.core.jatmi.jar:${LIBS}/image-sender.jar


JMS_SERVERS=$(env | sort | grep "^JMS_SERVER_URL_")
for JMS_SERVER in ${JMS_SERVERS};
do
  while IFS='|' read -r JMS_SERVER_URL JMS_SERVER_NAME;
  do
    f_logInfo "Processing ${JMS_SERVER} remove messages from ${SOURCE_QUEUE} with JMS Message Id ${IDENTIFIERS}"
    #./remove-jms.sh ${JMS_SERVER_NAME}@${SOURCE_QUEUE} ${JMS_SERVER_URL} ${WEBLOGIC_ADMIN_USERNAME} ${ADMIN_PASSWORD} "${IDENTIFIERS}" ${NUMBER_OF_MESSAGES}
    /usr/java/jdk/bin/java -cp ${CLASSPATH} -Dweblogic.security.SSL.ignoreHostnameVerification=true -Dweblogic.MaxMessageSize=100000000 chaps.jms.RemoveJMSMessages ${JMS_SERVER_NAME}@${SOURCE_QUEUE} ${JMS_SERVER_URL} ${WEBLOGIC_ADMIN_USERNAME} ${ADMIN_PASSWORD} "${IDENTIFIERS}" ${NUMBER_OF_MESSAGES}

  done < <(echo ${JMS_SERVER##*=})
done
