#!/bin/bash


cd /apps/oracle/doc1-producer

# set umask so that output files can be archived/tidied up by other users
umask 000

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

# set up logging
LOGS_DIR=../logs/doc1-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-doc1-producer-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

# Enable std Cloud batch logging via stdout whilst also supporting ability for invoking scripts to capture it too
# so that calling script can redirect stdout too thus be able to log independently.
# exec > changes stdout to refer to what comes next
# being process substitution of >(tee "${LOG_FILE}") to feed std program input 
# 2>&1 to redirect stderr to same place as stdout
# Net impact is to changes current process std output so output from following commands goto the tee process
exec > >(tee "${LOG_FILE}") 2>&1

PROPERTIES=$1   # Doc1 Properties File
CONFIG=$2       # Doc1 Config File
INDIR=$3        # Input directory
OUTDIR=$4       # Output directory

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting doc1-producer"

/usr/java/jdk-8/bin/java -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xmx1G -Din=doc1-producer -cp $CLASSPATH uk.gov.companieshouse.doc1producer.Doc1Producer $PROPERTIES $CONFIG $INDIR $OUTDIR
if [ $? -gt 0 ]; then
        f_logError "Non-zero exit code for doc1-producer java execution"
        exit 1
fi

f_logInfo "Ending doc1-producer"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
