#!/bin/bash

# =============================================================================
#
#  This script is used to list stuck ImageApiErrorQueue JMS messages in the ImageApiMessageProducerErrorQueue   
#  on all JMS servers.
#
#  It will display messages on each JMS server and show the object id 
#  (which is useful in the Weblogic console),  E.g: OBJECT_ID JMSSERVER_URL PAYLOAD_NAME PAYLOAD_JSON
#  2023-07-06T15:41:51,709 [list-all-jms-ef-responses.sh] INFO  745471.1697731224545.0  t3s://chips-ef-batch0.live.heritage.aws.internal:21031  TiffStreamPayload  {   "document_type": "RP05",   "category": "miscellaneous",   "barcode": "RCD2E3DK" ...}
#
#
#  One or more environment variables that list the connection details for the JMS Servers on which to 
#  perform the list operation. These variables must be called JMS_SERVER_URL_#
#  (where # is a unique identifier such as a number).  E.g.
#
#  JMS_SERVER_URL_1=t3s://chips-ef-batch0.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_2=t3s://chips-ef-batch1.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_3=t3s://chips-users-rest0.heritage.aws.internal:21031|JMSServer1
#  JMS_SERVER_URL_4=t3s://chips-users-rest1.heritage.aws.internal:21031|JMSServer1
#
#  WEBLOGIC_ADMIN_USERNAME - Weblogic admin user
#  ADMIN_PASSWORD - Weblogic admin password
#  EWF_ADMIN_PROXY_HOST - proxy server host to allow https access to ewf admin website
#  EWF_ADMIN_PROXY_PORT - proxy server port
#  EWF_ADMIN_HOST - FQDN of the ewf admin website
#  EWF_ADMIN_USER - username to login with
#  EWF_ADMIN_PASSWORD - password to login with
# =============================================================================

cd /apps/oracle/admin/jms

# load variables created from setCron script
source /apps/oracle/env.variables

# set up logging
LOGS_DIR=../../logs/jms
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-list-all-jms-image-error-queue-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec > >(tee "${LOG_FILE}") 2>&1

QUEUE=uk.gov.ch.chips.jms.ImageApiMessageProducerErrorQueue

JMS_SERVERS=$(env | sort -k1.18 | grep "^JMS_SERVER_URL_")
for JMS_SERVER in ${JMS_SERVERS};
do
  while IFS='|' read -r JMS_SERVER_URL JMS_SERVER_NAME;
  do
    f_logInfo "Processing ${JMS_SERVER} listing messages in ${QUEUE}"

    ./list-jms.sh ${JMS_SERVER_NAME}@${QUEUE} ${JMS_SERVER_URL} ${WEBLOGIC_ADMIN_USERNAME} ${ADMIN_PASSWORD} | grep -A 1 -C 1 "TiffStreamPayload" | paste - - | grep -E "barcode>|ObjectMessage" | uniq | sed 's/.*<//g' | sed 's/>.*BatchPayload\(.*]\)//g' | sed 's/|//g' > list-all-jms-image-error-queue.out
    while IFS=" " read OBJECT_ID JMSSERVER_URL PAYLOAD_NAME PAYLOAD_JSON
    do

      f_logInfo "${OBJECT_ID} ${JMSSERVER_URL} ${PAYLOAD_NAME} ${PAYLOAD_JSON}"

    done < list-all-jms-image-error-queue.out

  done < <(echo ${JMS_SERVER##*=})
done
