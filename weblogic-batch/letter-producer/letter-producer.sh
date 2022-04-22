#!/bin/bash

cd /apps/oracle/letter-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < letter-producer.properties.template > letter-producer.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/wlfullclient.jar:/apps/oracle/libs/log4j.jar:/apps/oracle/letter-producer/letter-producer.jar

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

#TODO as part of process compliance script: consider how logging will be handled - here or process compliance or both? (tee like image regen?)
# set up logging
LOGS_DIR=../logs/letter-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-letter-producer-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting letter-producer"

#TODO as part of process compliance script: keep here or move to controlling script in process compliance?
f_logInfo "Checking that letter-producer is not already running"
../scripts/check-for-jms-message.sh ${JMS_LETTERPRODUCERQUEUE}
if [ $? -gt 0 ]; then
        f_logError "letter-producer may be already running or connection error.  Please investigate."
        patrol_log_alert_chaps_f " `pwd`/`basename $0`:  letter-producer may be already running or connection error.  Please investigate."
        exit 1
fi

/usr/java/jdk-8/bin/java -Din=letter-producer -cp $CLASSPATH -Dlog4j.configuration=log4j.xml uk.gov.companieshouse.letterproducer.LetterProducerRunner letter-producer.properties
if [ $? -gt 0 ]; then
        f_logError "Non-zero exit code for letter-producer java execution"
        exit 1
fi

f_logInfo "Ending letter-producer"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
