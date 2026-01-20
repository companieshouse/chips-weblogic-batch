#!/bin/bash

cd /apps/oracle/compliance-trigger

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < compliance-trigger.properties.template > compliance-trigger.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/log4j-1.2-api.jar:/apps/oracle/libs/log4j-api.jar:/apps/oracle/libs/log4j-core.jar:/apps/oracle/libs/ojdbc11.jar:/apps/oracle/compliance-trigger/compliance-trigger.jar

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

# set up logging
LOGS_DIR=../logs/compliance-trigger
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-compliance-trigger-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

# Enable std Cloud batch logging via stdout whilst also supporting ability for invoking scripts to capture it too
# so that calling script can redirect stdout too thus be able to log independently.
# exec > changes stdout to refer to what comes next
# being process substitution of >(tee "${LOG_FILE}") to feed std program input 
# 2>&1 to redirect stderr to same place as stdout
# Net impact is to changes current process std output so output from following commands goto the tee process
exec > >(tee "${LOG_FILE}") 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting compliance-trigger"

/usr/java/jdk/bin/java -Din=compliance-trigger -cp $CLASSPATH -Dlog4j.configuration=log4j.xml uk.gov.companieshouse.compliance.trigger.ComplianceTrigger compliance-trigger.properties
if [ $? -gt 0 ]; then
        f_logError "Non-zero exit code for compliance-trigger java execution"
        exit 1
fi

f_logInfo "Ending compliance-trigger"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
