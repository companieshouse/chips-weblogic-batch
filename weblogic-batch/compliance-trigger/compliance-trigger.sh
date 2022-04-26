#!/bin/bash

cd /apps/oracle/compliance-trigger

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < compliance-trigger.properties.template > compliance-trigger.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/log4j.jar:/apps/oracle/libs/ojdbc8.jar:/apps/oracle/compliance-trigger/compliance-trigger.jar

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

#TODO as part of process compliance script: consider how logging will be handled - here or process compliance or both? (tee like image regen?)
# set up logging
LOGS_DIR=../logs/compliance-trigger
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-compliance-trigger-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting compliance-trigger"

/usr/java/jdk-8/bin/java -Din=compliance-trigger -cp $CLASSPATH -Dlog4j.configuration=log4j.xml uk.gov.companieshouse.compliance.trigger.ComplianceTrigger compliance-trigger.properties
if [ $? -gt 0 ]; then
        f_logError "Non-zero exit code for compliance-trigger java execution"
        exit 1
fi

f_logInfo "Ending compliance-trigger"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
