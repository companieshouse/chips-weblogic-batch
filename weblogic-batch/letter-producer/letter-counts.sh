#!/bin/bash

cd /apps/oracle/letter-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst < ../.msmtprc.template > ../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/letter-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-letter-counts-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting letter-counts"
DATE=`date +%Y-%m-%d`

DIR=`ls -d /apps/oracle/chipsdomain/batch/doc1ProducerOutput/$DATE*`

#Non zero exit code
if [ ! $? -eq 0 ] ; then
  email_CHAPS_group_f "Daily Letters Produced: Overrun or Failed" "Due to overun or failure, cannot find directory yet for date ${DATE}"
  exit 1
fi

f_logInfo "$DIR"
cd "$DIR"

#Clear letter_tots file
>/tmp/letter_tots

# SCOTLAND and SVOL are not excluded
for FILE in `find . -name '*' -print |  grep -v ERROR | grep -v SCDOC1CES | grep -v WSOLE | grep -v WSOLW | grep -v 'CERTSSC.TXT' | grep -v 'CHVOLCER/RETCERT' | grep -v 'CHVOLCER/DOC1CES' | grep -v 'NIRETCERT' | grep -v 'NIDOC1CES' | grep -v 'DEF49EW' | grep -v 'WDEF49EW' | grep -v 'NIDEF49' | grep -v 'MORTEW' | grep -v 'MORTBI' | grep -v 'MORTSC' | grep -v 'MORTNI' `
do
  #If $FILE is a file not a directory
  if [ -f "$FILE" ] ; then
    #strip off leading path
    FILENAME=`basename "$FILE"`
    echo "$FILE":`grep -c 107000 $FILE` | tee -a /tmp/letter_tots
  fi
done

#Sort file, and strip out leading dot slash (./)
sort /tmp/letter_tots | sed 's/.\///' > /tmp/letter_no_tots

email_report_CHAPS_group_f "Daily Letters File Sent to APS" "`cat /tmp/letter_no_tots`"

f_logInfo "Ending letter-counts"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
