#!/bin/bash

cd /apps/oracle/scripts

# load variables created from setCron script if needed
source /apps/oracle/env.variables

if [ -z "$1" ]; then
    echo `date`": Unable to confirm if process is already running on - no queue name passed as a parameter."
    exit 1
fi
QUEUE_NAME=$1

JNDI_QUEUE_NAME=${JMS_SERVER_NAME}@${QUEUE_NAME}
URL=${JMS_JNDIPROVIDERURL}
USERNAME=${WEBLOGIC_ADMIN_USERNAME}
PASSWORD=${ADMIN_PASSWORD}
RESULT=1

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs//wlfullclient.jar:/apps/oracle/libs/log4j.jar:/apps/oracle/libs/jmstool.jar

## Check 1p server
UNPROCESSEDCOUNT=`/usr/java/jdk-8/bin/java -cp $CLASSPATH chaps.jms.JMSQueueStats $JNDI_QUEUE_NAME $URL $USERNAME $PASSWORD | grep UNPROCESSED | awk -F: '{print $2}'`

if [ -z "$UNPROCESSEDCOUNT" ]; then
  echo `date`": Unable to confirm if process is already running on - possible issue with connection to Weblogic or other problem."
  exit 1
fi

if [ "$UNPROCESSEDCOUNT" -eq 0 ]; then
  echo `date`": OK. No unprocessed messages detected in ${QUEUE_NAME}."
  exit 0
fi

## if we find a message on 1p, process already running so exit one.
if [ "$UNPROCESSEDCOUNT" -gt 0 ]; then
  echo `date`": Message detected in ${QUEUE_NAME}.  Process still processing  ..."
  exit 1
fi

exit $RESULT
