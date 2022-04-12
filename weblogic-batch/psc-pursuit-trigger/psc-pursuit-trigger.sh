#!/bin/bash

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < psc-pursuit-trigger.properties.template > psc-pursuit-trigger.properties

LIBS_DIR=/apps/oracle/libs
CLASSPATH=${CLASSPATH}:.:${LIBS_DIR}/log4j-api.jar:${LIBS_DIR}/log4j-core.jar:${LIBS_DIR}/ojdbc8.jar:/apps/oracle/psc-pursuit-trigger/psc-pursuit-trigger.jar

# Set up mail config for msmtp & load alerting functions
envsubst < ../.msmtprc.template > ../.msmtprc
source /apps/oracle/scripts/alert_functions
source /apps/oracle/scripts/logging_functions

# set up logging
LOGS_DIR=/apps/oracle/logs/psc-pursuit-trigger
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-psc-pursuit-trigger-$(date +'%Y-%m-%d_%H-%M-%S').log"

exec >> "${LOG_FILE}" 2>&1

cd /apps/oracle/psc-pursuit-trigger || { f_logError "psc-pursuit-trigger directory error" ; exit 1 ; }

f_logInfo  "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting psc-pursuit-trigger"

/usr/java/jdk-8/bin/java -Din=psc-pursuit-trigger -cp "${CLASSPATH}" -Dlog4j.configurationFile=log4j2.xml uk.gov.companieshouse.psc.pursuit.trigger.PscPursuitTrigger psc-pursuit-trigger.properties

exit_code=$?
if [ $exit_code -gt 0 ]
then
  f_logError "Non-zero exit code for psc-pursuit-trigger java execution. The exit code was %s." "${exit_code}"
  email_CHAPS_group_f "psc-pursuit-trigger failed. " "$(pwd)/$(basename "$0") psc-pursuit-trigger trigger exit code of ${exit_code} indicates failure. Please investigate."
  exit 1
fi

f_logInfo "Ending psc-pursuit-trigger"
f_logInfo  "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
