#!/bin/bash

#   PURPOSE: Officer wrapper script that will process individual Officer Events from a list in a file
#   NOTE: Because the standard process looks for data from a week ago (configured in batch params),
#   we will need to run SQL to change event timestamps placed by this script into OFFICER_EVENT_MATCH
#   before the next Officer run. This updates OFFICER_EVENT_MATCH with matches using SYSDATE
#
#   You need to change timestamp to Catchup's BPP: example
#   update OFFICER_EVENT_MATCH o set o.EVENT_TMSP=to_date('28-MAR-2008','DD-MON-YYYY')  -- this is Catchup date
#   where o.EVENT_TMSP = to_date('04-DEC-2008 13:31:26','DD-MON-YYYY HH24:MI:SS')       -- this is runtime (Today) date
#
#   After this run, then you just run normal Officer Catchup (stages 2 & 3), which will pick these up.

function check_error_lock_file {
  if [ -f /apps/oracle/officer-bulk-process/OFFICER_LOCK_FILE_ALERT ]; then
    f_logError "OFFICER_LOCK_FILE_ALERT exists. Previous run failed."
    email_CHAPS_group_f " $(pwd)/$(basename $0): OFFICER_LOCK_FILE_ALERT exists. Previous run failed."
    exit 1
  fi
}

function set_error_lock_file {
  touch /apps/oracle/officer-bulk-process/OFFICER_LOCK_FILE_ALERT
}

function remove_running_lock_file {
  rm /apps/oracle/officer-bulk-process/OFFICER_RUNNING
}

function set_running_lock_file {
  touch /apps/oracle/officer-bulk-process/OFFICER_RUNNING
}

function check_running_lock_file {
  if [ -f /apps/oracle/officer-bulk-process/OFFICER_RUNNING ]; then
    f_logError "OFFICER_RUNNING lock file exists. Officer already running."
    email_CHAPS_group_f " $(pwd)/$(basename $0): OFFICER_RUNNING lock file exists. Officer already running."
    exit 1
  fi
}

cd /apps/oracle/officer-bulk-process

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst <officer-poller.properties.template >officer-poller.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs/xstream.jar:/apps/oracle/libs/cglib-nodep.jar:/apps/oracle/libs/joda-time.jar:/apps/oracle/libs/commons-lang.jar:/apps/oracle/libs/ojdbc11.jar:/apps/oracle/libs/wlthint3client.jar:/apps/oracle/libs/spring.jar:/apps/oracle/libs/log4j-core.jar:/apps/oracle/libs/log4j-api.jar:/apps/oracle/libs/log4j-1.2-api.jar:/apps/oracle/libs/com.bea.core.datasource6.jar:/apps/oracle/libs/com.bea.core.resourcepool.jar:/apps/oracle/libs/com.oracle.weblogic.jdbc.jar:/apps/oracle/officer-bulk-process/officer-bulk-process.jar
JAVA_ARGS="--add-opens=java.desktop/java.awt.font=ALL-UNNAMED --add-opens=java.base/java.text=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED"

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/officer-bulk-process
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-officer-bulk-process-single-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

if [[ $# > 1 ]]; then
  f_logError "Failed to start officer-bulk-process-single: Too many parameters, only expects a filename (defaults to officerIDs.xml)"
  exit 1
fi
## set file of officers - defaults to officerIDs.xml
## you can pass in different ones as args
if [[ -z $1 ]]; then
  FILE=officerIDs.xml
else
  FILE=$1
fi

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting Officer SINGLE"

## Check if previous run has failed or job already running, exit and alert
check_error_lock_file
check_running_lock_file

## Set running file to prevent duplicate running
set_running_lock_file

## REAL WORK BEGINS

## Run FIRST stage of Officer job - EVENT
f_logInfo "Run FIRST stage of Officer job - EVENT  - SINGLE mode using ${FILE}"
/usr/java/jdk/bin/java ${JAVA_ARGS} -Din=officer-bulk-process -cp $CLASSPATH -Dlog4j.configurationFile=log4j2.xml \
  uk.gov.companieshouse.officerbulkprocess.OfficerDetailEventPoller normal ${JMS_JNDIPROVIDERURL} bulk-officer.xml ${FILE}

if [ $? -gt 0 ]; then
  f_logError "Non-zero exit code for FIRST stage officer SINGLE java execution"
  remove_running_lock_file
  set_error_lock_file
  email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for FIRST stage officer SINGLE java execution."
  exit 1
fi

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Zero return code for EVENT stage of Officer job SINGLE  - EVENT. Exit probably successful"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

## Remove running lock file
##
remove_running_lock_file

f_logInfo "Ending Officer SINGLE"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "REMEMBER TO RESET TIMESTAMP IN OFFICER_EVENT_MATCH"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
