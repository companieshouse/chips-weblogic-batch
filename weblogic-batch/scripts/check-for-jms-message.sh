#!/bin/bash

cd /apps/oracle/scripts

# load variables created from setCron script if needed
source /apps/oracle/env.variables
# load logging functions
source logging_functions

USAGE_MSG="Usage: check-for-jms-message.sh QUEUE_NAME [PROCESS_STATE(STOPPED|RUNNING)]"
if [ -z "$1" ]; then
  f_logError "Unable to confirm if process is already running - no queue name passed as a parameter."
  f_logError "${USAGE_MSG}"
  exit 2
fi
QUEUE_NAME=$1
PROCESS_STATE="STOPPED"
if [[ $# > 1 ]]; then
  case $2 in
  "STOPPED") ;;
  "RUNNING")
    PROCESS_STATE="RUNNING"
    ;;
  *)
    f_logError "Invalid value for PROCESS_STATE was supplied. Value supplied was: %s" "${2}"
    f_logError "${USAGE_MSG}"
    exit 1
    ;;
  esac
fi
RESULT=1

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs//wlthint3client.jar:/apps/oracle/libs/log4j-1.2-api.jar:/apps/oracle/libs/log4j-api.jar:/apps/oracle/libs/log4j-core.jar:/apps/oracle/libs/jmstool.jar:/apps/oracle/libs/com.oracle.weblogic.jms.jar:/apps/oracle/libs/com.oracle.weblogic.management.mbeanservers.jar:/apps/oracle/libs/com.oracle.weblogic.management.base.jar:/apps/oracle/libs/com.bea.core.management.core.jar:/apps/oracle/libs/com.bea.core.management.jmx.jar:/apps/oracle/libs/com.bea.core.utils.jar:/apps/oracle/libs/com.oracle.weblogic.management.core.api.jar:/apps/oracle/libs/com.bea.core.weblogic.lifecycle.jar:/apps/oracle/libs/com.oracle.weblogic.security.jar:/apps/oracle/libs/com.oracle.weblogic.management.config.api.jar

## Check 1p server
UNPROCESSEDCOUNT=$(/usr/java/jdk/bin/java -cp $CLASSPATH chaps.jms.JMSQueueStats ${JMS_SERVER_NAME}@${QUEUE_NAME} ${JMS_JNDIPROVIDERURL} ${WEBLOGIC_ADMIN_USERNAME} ${ADMIN_PASSWORD} | grep UNPROCESSED | awk -F: '{print $2}')

if [ -z "$UNPROCESSEDCOUNT" ]; then
  f_logError "Unable to confirm if process is already running - possible issue with connection to Weblogic or other problem."
  exit 2
fi

if [ "$PROCESS_STATE" = "RUNNING" ]; then
  # in RUNNING mode - checking for messages when process SHOULD be running
  if [ "$UNPROCESSEDCOUNT" -eq 0 ]; then
    f_logError "No unprocessed messages detected in ${QUEUE_NAME} - job may have failed during processing."
    exit 1
  fi

  ## if we find a message on 1p, process running as expected.
  if [ "$UNPROCESSEDCOUNT" -gt 0 ]; then
    f_logInfo "Message detected in ${QUEUE_NAME}.  Process still processing  ..."
    exit 0
  fi

elif [ "$PROCESS_STATE" = "STOPPED" ]; then
  # in default STOPPED mode - checking for NO messages when process should be stopped
  if [ "$UNPROCESSEDCOUNT" -eq 0 ]; then
    f_logInfo "OK. No unprocessed messages detected in ${QUEUE_NAME}."
    exit 0
  fi

  ## if we find a message on 1p, process already running so exit one.
  if [ "$UNPROCESSEDCOUNT" -gt 0 ]; then
    f_logError "Message detected in ${QUEUE_NAME}.  Process still processing  ..."
    exit 1
  fi

fi

exit $RESULT
