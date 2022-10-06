#!/bin/bash

cd /apps/oracle/scripts

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst < ../.msmtprc.template > ../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/cron
mkdir -p ${LOGS_DIR}
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-track-crontab-changes-${TIMESTAMP}.log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting track-crontab-changes"

USERNAME="weblogic"
HOST="batch"
BACKUPFOLDERPATH=${LOGS_DIR}
BAKLIMIT=50

cd ${BACKUPFOLDERPATH}
NEWFILE=${USERNAME}_${HOST}_crontab.current

#Get previous crontab filename
PREVIOUSFILE=`ls -1rt ${USERNAME}_${HOST}_crontab.bak* | tail -1`

if [ -z ${PREVIOUSFILE} ]; then
   f_logInfo "No previous backups found - so creating new one"
   crontab -l > ${USERNAME}_${HOST}_crontab.bak.$TIMESTAMP
   exit 0
fi

f_logInfo "Previous file: ${PREVIOUSFILE}"

crontab -l > ${NEWFILE}

#Diff the previous one with the current one
diff ${PREVIOUSFILE} ${NEWFILE}
DIFFOUT=$?
f_logInfo "Output after diff" ${DIFFOUT}

BAKCOUNT=`ls -1rt ${USERNAME}_${HOST}_crontab.bak.* | wc -l`
f_logInfo "Backup count: ${BAKCOUNT}"

if [ ${DIFFOUT} -gt 0 ];
then
  ## There was a difference so..
  ## Backup current crontab
  cp ${NEWFILE} ${USERNAME}_${HOST}_crontab.bak.$TIMESTAMP

  ## Email an alert
  {
  echo "Current crontab compared with previous version ${PREVIOUSFILE}:"
  echo "(< indicates previous crontab, > is the current one)"
  echo
  diff ${PREVIOUSFILE} ${NEWFILE}
  echo
  echo
  echo "The latest crontab has been saved as ${USERNAME}_${HOST}_crontab.bak.${TIMESTAMP}."
  echo "The $(( ${BAKCOUNT} )) previous crontabs for ${USERNAME}@${HOST} are also preserved in ${PWD}."
  } > /tmp/cron_diff_msg
  email_report_CHAPS_group_f "crontab change tracked for ${USERNAME}@${HOST}" "$(cat /tmp/cron_diff_msg)"
fi

if [ ${BAKCOUNT} -ge ${BAKLIMIT} ]; then

   ##  Find the oldest backup
   OLDESTBACKUP=`ls -1t ${USERNAME}_${HOST}_crontab.bak* | tail -1`

   ##  Removing ${OLDESTBACKUP}
   rm ${OLDESTBACKUP}
fi

rm ${NEWFILE}

f_logInfo "Ending track-crontab-changes script"
