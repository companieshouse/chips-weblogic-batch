#!/bin/bash


cd /apps/oracle/doc1-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < doc1-producer.properties.template > doc1-producer.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-lang.jar:/apps/oracle/libs/ojdbc8.jar:/apps/oracle/libs/jdom.jar:/apps/oracle/doc1-producer/doc1-producer.jar

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

#TODO as part of process compliance script: consider how logging will be handled - here or process compliance or both? (tee like image regen?)
# set up logging
LOGS_DIR=../logs/doc1-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-doc1-producer-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

PROPERTIES=$1   # Doc1 Properties File
CONFIG=$2       # Doc1 Config File
INDIR=$3        # Input directory
OUTDIR=$4       # Output directory

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting doc1-producer"

/usr/java/jdk-8/bin/java -Din=doc1-producer -cp $CLASSPATH uk.gov.companieshouse.doc1producer.Doc1Producer $PROPERTIES $CONFIG $INDIR $OUTDIR
if [ $? -gt 0 ]; then
        f_logError "Non-zero exit code for doc1-producer java execution"
        exit 1
fi

f_logInfo "Ending doc1-producer"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
