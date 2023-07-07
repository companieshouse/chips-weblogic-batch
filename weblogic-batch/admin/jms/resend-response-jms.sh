#!/bin/bash

# =============================================================================
#
#  This script is used to resend an accept response for EWF/XML docs by
#  creating a new JMS message from an xml document that has been manually taken 
#  from the TRANSACTION_DOC_XML table on the CHIPS OLTP database. 
#
#  This script expects two parameters:
#
#  XML_PATH - the path to the xml file
#  STATUS - accept or reject
#
#  In addition to those, it also expects an environment variable
#  that holds the connection details for a JMS Server on which to
#  create the message. The variable must be called JMS_SERVER_URL_1
#
#  JMS_SERVER_URL_1=t3s://chips-ef-batch0.heritage.aws.internal:21031|JMSServer1
#
#  This script is intended to be called directly.
# 
# =============================================================================

cd /apps/oracle/admin/jms

# load variables created from setCron script
source /apps/oracle/env.variables

# set up logging
LOGS_DIR=../../logs/jms
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-resend-response-jms-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec > >(tee "${LOG_FILE}") 2>&1

if [ "$#" -ne 2 ]
then
  f_logError "Invalid number of arguments - expected 2"
  f_logInfo "Usage: ./resend-response-jms.sh <path to xml file> <status>"
  f_logInfo "Example: ./resend-response-jms.sh a.xml reject"
  exit 1
fi

XML_FILE=$1
STATUS=$2
JMS_SERVER_URL=${JMS_SERVER_URL_1%%|*}
JMS_SERVER_NAME=${JMS_SERVER_URL_1##*|}

f_logInfo "Processing ${JMS_SERVER} injecting JMS message from ${XML_FILE} with a status of ${STATUS}"
./inject-jms.sh ${XML_FILE} ${STATUS} ${JMS_SERVER_NAME}@uk.gov.ch.chips.jms.EfilingQueue ${JMS_SERVER_URL} ${WEBLOGIC_ADMIN_USERNAME} ${ADMIN_PASSWORD}