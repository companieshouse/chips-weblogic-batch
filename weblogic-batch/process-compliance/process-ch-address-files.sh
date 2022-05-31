#!/bin/bash

cd /apps/oracle/process-compliance

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < process-compliance.properties.template > process-compliance.properties
source process-compliance.properties

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

# Set up standard logging
LOGS_DIR=../logs/process-compliance
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-process-ch-address-files-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> "${LOG_FILE}" 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting process-ch-address-files script." 

if [ -z ${AFP_INPUT_LOCATION} ]; then
  f_logError "AFP_INPUT_LOCATION not set - please edit properties"  ; exit 1
fi

if [ -z ${AFP_OUTPUT_LOCATION} ]; then
  f_logError "AFP_OUTPUT_LOCATION not set - please edit properties"  ; exit 1
fi

if [ -z ${DOC1FILE_CH_ADDRESS_DIR} ]; then
  f_logError "DOC1FILE_CH_ADDRESS_DIR not set - please edit properties"  ; exit 1
fi

# Copy the files in DOC1FILE_CH_ADDRESS_DIR to the AFP_INPUT_LOCATION.  This  will ensure that the afp files are
# generated and moved into Smartview.  The files are not sent to APS, so won't be printed and mailed back to us.

f_logInfo "DOC1FILE_CH_ADDRESS_DIR is ${DOC1FILE_CH_ADDRESS_DIR}"

if [ -d "${DOC1FILE_CH_ADDRESS_DIR}" ]; then
  f_logInfo "${DOC1FILE_CH_ADDRESS_DIR} exists"
  OUTPUTFILE_CH_ADDRESS_LIST=`find ${DOC1FILE_CH_ADDRESS_DIR} -type f`

  f_logInfo "OUTPUTFILE_CH_ADDRESS_LIST is ${OUTPUTFILE_CH_ADDRESS_LIST}"
  NUMBER_OF_FILES_MOVED_TO_AFP_INPUT=0
  for OUTPUTFILE_CH_ADDRESS in ${OUTPUTFILE_CH_ADDRESS_LIST}
  do
    ((NUMBER_OF_FILES_MOVED_TO_AFP_INPUT=NUMBER_OF_FILES_MOVED_TO_AFP_INPUT + 1))
    OUTPUTFILENAME_CH_ADDRESS=${OUTPUTFILE_CH_ADDRESS##*/}
    f_logInfo "Copying ${OUTPUTFILE_CH_ADDRESS} to ${AFP_INPUT_LOCATION}/${OUTPUTFILENAME_CH_ADDRESS}"
    cp  ${OUTPUTFILE_CH_ADDRESS} ${AFP_INPUT_LOCATION}/${OUTPUTFILENAME_CH_ADDRESS}
  done

  f_logInfo "NUMBER_OF_FILES_MOVED_TO_AFP_INPUT is ${NUMBER_OF_FILES_MOVED_TO_AFP_INPUT}"

  if [ $NUMBER_OF_FILES_MOVED_TO_AFP_INPUT -gt 0 ] ; then

     NUMBER_OF_FILES_IN_AFP_OUTPUT_FOLDER=0
     AFP_CHECK_COUNT=0;
     SLEEP_SECS=30;

     while [ $NUMBER_OF_FILES_IN_AFP_OUTPUT_FOLDER -lt $NUMBER_OF_FILES_MOVED_TO_AFP_INPUT ] && [ $AFP_CHECK_COUNT -lt 10 ]
     do
        f_logInfo "AFP File Count is $NUMBER_OF_FILES_IN_AFP_OUTPUT_FOLDER and expecting $NUMBER_OF_FILES_MOVED_TO_AFP_INPUT ... sleeping for ${SLEEP_SECS} seconds"
        sleep ${SLEEP_SECS}
        ((AFP_CHECK_COUNT=AFP_CHECK_COUNT + 1))

        NUMBER_OF_FILES_IN_AFP_OUTPUT_FOLDER=`ls -1 ${AFP_OUTPUT_LOCATION}/*CH_ADDRESS* | wc -l`
        f_logInfo "NUMBER_OF_FILES_IN_AFP_OUTPUT_FOLDER is ${NUMBER_OF_FILES_IN_AFP_OUTPUT_FOLDER}"
     done
     f_logInfo "Removing processed afp files - available in SmartView or Doc1 server archives if needed"
     f_logInfo "List of files in ${AFP_OUTPUT_LOCATION} is"
     ls -l ${AFP_OUTPUT_LOCATION} | while IFS= read -r line; do f_logInfo "$line"; done
     if [[ -d ${AFP_OUTPUT_LOCATION} ]] ; then
       rm -rf ${AFP_OUTPUT_LOCATION}/*
     fi
  fi

  f_logInfo "CH address letters stats for current run:"
  find ${DOC1FILE_CH_ADDRESS_DIR} -name "*" -type f -exec wc -l {} + | while IFS= read -r line; do f_logInfo "$line"; done

  # DOC1FILE_CH_ADDRESS_DIR is docker mount dir so can't move - moving contents instead
  DATED_DIR=${DOC1FILE_CH_ADDRESS_DIR_ARCHIVE}/$(basename ${DOC1FILE_CH_ADDRESS_DIR}).$(date +'%Y-%m-%d_%H-%M-%S')
  f_logInfo "Moving ${DOC1FILE_CH_ADDRESS_DIR} contents to ${DATED_DIR}"
  mkdir ${DATED_DIR}
  mv ${DOC1FILE_CH_ADDRESS_DIR}/* ${DATED_DIR}/

fi
f_logInfo "process-ch-address-files ends"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
