#!/bin/bash

# =============================================================================
#
#  This script is used to import JMS messages from a file 
#  read the objects and save them into the queue and repeat   
# 
#  This script expects three parameters:
#  EXPORT_PATH - the path to import messages from, e.g /tmp/
#  NUMBER OF MESSAGES - the number of messages to move, e.g. 500
#  EXPORT_DATA_FILE - the name of the file to import, e.g. import-file.xml
#  This script is intended to be called manually.
#  
# =============================================================================

cd /apps/oracle/admin/jms

# load variables created from setCron script
source /apps/oracle/env.variables

# set up logging
LOGS_DIR=../../logs/jms
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-import-jms-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec > >(tee "${LOG_FILE}") 2>&1
f_logInfo "Starting import-jms-messages.sh with parameters: $*"
if [ "$#" -ne 3 ]
then
  f_logError "Invalid number of arguments - expected 3"
  f_logInfo "Usage: ./import-jms-messages.sh.sh <export path> <number of messages> <import file name>"
  f_logInfo "Example: ./import-jms-messages.sh.sh /tmp/ 500 import-file.xml"
  exit 1
fi


EXPORT_PATH="$1"
NUMBER_OF_MESSAGES=$2
EXPORT_DATA_FILE=$3
LIBS=/apps/oracle/libs
CLASSPATH=${LIBS}/jmstool.jar:${LIBS}/log4j-1.2-api.jar:${LIBS}/log4j-api.jar:${LIBS}/log4j-core.jar:${LIBS}/jms-api.jar:${LIBS}/wlthint3client.jar:${LIBS}/jdom.jar:${LIBS}/chips-common.jar:${LIBS}/com.bea.core.jatmi.jar:${LIBS}/image-sender.jar

f_logInfo "Processing ${EXPORT_DATA_FILE} "
/usr/java/jdk/bin/java -cp ${CLASSPATH} -Dweblogic.security.SSL.ignoreHostnameVerification=true -Dweblogic.MaxMessageSize=100000000 chaps.jms.ImportJMSMessages  ${WEBLOGIC_ADMIN_USERNAME} ${ADMIN_PASSWORD} "${EXPORT_PATH}" ${NUMBER_OF_MESSAGES} ${EXPORT_DATA_FILE}


