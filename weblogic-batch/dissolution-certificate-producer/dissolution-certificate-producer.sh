#!/bin/bash

##  This script will fire all XML files in the defined directory in turn to the DissolutionCertificate JMS queue
##  Its primary use is as a bulk test harness for dissolution certificate production. However, it is also useful
##  for reprocessing a list of XML files that may have failed or need new images for whatever reason.

##  dissolution-certificate-producer.sh: Shell wrapper to run the dissolution-certificate-producer.jar file
##  Options are -d <directory path> (required) -f <file name> (optional)

cd /apps/oracle/dissolution-certificate-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst <dissolution-certificate-producer.properties.template >dissolution-certificate-producer.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/wlfullclient.jar:/apps/oracle/libs/log4j.jar:/apps/oracle/libs/jdom.jar:/apps/oracle/dissolution-certificate-producer/dissolution-certificate-producer.jar

# set up logging
LOGS_DIR=../logs/dissolution-certificate-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-dissolution-certificate-producer-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

OPTS_TEXT="Options are -d <directory path> (required) -f <file name> (optional)"

while getopts :d:f: flag
do
  case "${flag}" in
    d) INDIR=${OPTARG};;
    f) INFILE=${OPTARG};;
    *) echo "Failed to start dissolution-certificate-producer: Unknown parameter value. ${OPTS_TEXT}";
       exit 1;;
  esac
done

shift $(($OPTIND - 1))
if [[ $# > 0 ]]; then
        echo "Failed to start dissolution-certificate-producer: Unexpected parameter(s) $@. ${OPTS_TEXT}"
        exit 1
fi
if [[ ! -d ${INDIR} ]]; then
    echo "Failed to start dissolution-certificate-producer: ${INDIR} is not a directory. ${OPTS_TEXT}";
    exit 1
fi

echo "Check ${LOG_FILE} for log output."

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting dissolution-certificate-producer"
f_logInfo "Input directory path: $INDIR (filename, if given: $INFILE)"

/usr/java/jdk-8/bin/java -Din=dissolution-certificate-producer -cp $CLASSPATH uk.gov.companieshouse.dissolutioncerts.DissolutionCertsProducerRunner dissolution-certificate-producer.properties $INDIR $INFILE

if [ $? -gt 0 ]; then
    f_logError "Non-zero exit code for dissolution-certificate-producer java execution"
    exit 1
fi

f_logInfo "Ending dissolution-certificate-producer"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
