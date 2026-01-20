#!/bin/bash

cd /apps/oracle/letter-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < letter-producer.properties.template > letter-producer.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/wlthint3client.jar:/apps/oracle/libs/log4j-1.2-api.jar:/apps/oracle/libs/log4j-api.jar:/apps/oracle/libs/log4j-core.jar:/apps/oracle/letter-producer/letter-producer.jar

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

# set up logging
LOGS_DIR=../logs/letter-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-letter-producer-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

# Enable std Cloud batch logging via stdout whilst also supporting ability for invoking scripts to capture it too
# so that calling script can redirect stdout too thus be able to log independently.
# exec > changes stdout to refer to what comes next
# being process substitution of >(tee "${LOG_FILE}") to feed std program input 
# 2>&1 to redirect stderr to same place as stdout
# Net impact is to changes current process std output so output from following commands goto the tee process
exec > >(tee "${LOG_FILE}") 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting letter-producer"

f_logInfo "Checking that letter-producer is not already running"
../scripts/check-for-jms-message.sh ${JMS_LETTERPRODUCERQUEUE}
if [ $? -gt 0 ]; then
        f_logError "letter-producer may be already running or connection error.  Please investigate."
        patrol_log_alert_chaps_f " `pwd`/`basename $0`:  letter-producer may be already running or connection error.  Please investigate."
        exit 1
fi

/usr/java/jdk/bin/java --add-opens=java.base/java.io=ALL-UNNAMED -Din=letter-producer -cp $CLASSPATH uk.gov.companieshouse.letterproducer.LetterProducerRunner letter-producer.properties
if [ $? -gt 0 ]; then
        f_logError "Non-zero exit code for letter-producer java execution"
        exit 1
fi

f_logInfo "Ending letter-producer"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
