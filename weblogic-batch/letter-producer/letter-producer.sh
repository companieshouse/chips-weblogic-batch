#!/bin/bash

cd /apps/oracle/letter-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < letter-producer.properties.template > letter-producer.properties

# TODO: review / confirm classpath requirements
CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs/wlfullclient.jar:/apps/oracle/libs/log4j.jar:/apps/oracle/letter-producer/letter-producer.jar

# Set up mail config for msmtp & load alerting functions
envsubst < ../.msmtprc.template > ../.msmtprc
source ../scripts/alert_functions

#TODO: consider how logging will be handled - here or process compliance or both? (tee like image regen?)
# set up logging
LOGS_DIR=../logs/letter-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-letter-producer-$(date +'%Y-%m-%d_%H-%M-%S').log"

exec >> ${LOG_FILE} 2>&1

echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo `date` Starting letter-producer

#TODO: this will probably be moved to controlling script in process compliance
echo Checking that letter-producer is not already running
../scripts/check-for-jms-message.sh ${JMS_LETTERPRODUCERQUEUE}
if [ $? -gt 0 ]; then
        echo `date`": letter-producer may be already running or connection error.  Please investigate."
        patrol_log_alert_chaps_f " `pwd`/`basename $0`:  letter-producer may be already running or connection error.  Please investigate."
        exit 1
fi

/usr/java/jdk-8/bin/java -Din=letter-producer -cp $CLASSPATH -Dlog4j.configuration=log4j.xml uk.gov.companieshouse.letterproducer.LetterProducerRunner letter-producer.properties
if [ $? -gt 0 ]; then
        echo "Non-zero exit code for letter-producer java execution"
        exit 1
fi

echo `date` Ending letter-producer
echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
