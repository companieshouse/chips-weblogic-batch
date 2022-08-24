#!/bin/bash

# =============================================================================
#
#  This script is used to report on JMS messages in the ChipsGenericErrorQueue    
#  across all WebLogic servers.
#
# =============================================================================


smallBanner() {
 DASHES="------------------------------------------------------------------------------------"
 echo
 echo ${DASHES}
 echo $1
 echo ${DASHES}
 echo
}

reportStuckTextMessages() {
  MESSAGE_TYPE=$1
  TMP_DIR=$2

  FILES_WITH_MESSAGES=$(grep -lr ${MESSAGE_TYPE} ${TMP_DIR})
  EXIT_CODE=$?

  if [[ ${EXIT_CODE} -eq 0 ]]
  then

    smallBanner "Stuck ${MESSAGE_TYPE} messages - ($(grep -r ${MESSAGE_TYPE} ${TMP_DIR} | wc -l) of these)"

    for FILE in $FILES_WITH_MESSAGES
    do
      echo
      JMS_SERVER=$(head -1 ${FILE} | sed 's/.*\(chips-.*\):.*|\(JMSServer[0-9]*\).*/\1 \2/g')
      echo ":- ${JMS_SERVER}"
      echo
      grep ${MESSAGE_TYPE} $FILE | awk '{print $0,"\n"}'
      echo
    done
  fi
}

cd /apps/oracle/admin/jms

# load variables created from setCron script
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst <../../.msmtprc.template >../../.msmtprc
source ../../scripts/alert_functions

# set up logging
LOGS_DIR=../../logs/jms
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-report-stuck-chips-generic-messages-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec > >(tee "${LOG_FILE}") 2>&1

# Extract a list of submission xml from all jms servers
TMP_LIST_FILE=list-all-jms-chips-generic.output
./list-all-jms.sh uk.gov.ch.chips.jms.ChipsGenericErrorQueue > ${TMP_LIST_FILE}

# Split the list of stuck JMS messagest into individual files - one file for each JMS_SERVER
TMP_DIR=chips-generic.tmp
mkdir -p ${TMP_DIR}
awk -v var="${TMP_DIR}/" '/JMS_SERVER/{close(out);out=var "jms" ++i} {print > out}' ${TMP_LIST_FILE}

# Now create a report file
# Check for each message type in turn and add to the report file
TMP_REPORT_FILE=report-chips-generic.tmp

for MESSAGE_TYPE in EXTENSIONS_CONTACT HMRC_BULK_OBJECTIONS LFP_APPEAL_CONTACT PSC_DISCREPANCIES WEB_PSC_DISCREPANCIES PROMISE_TO_FILE OCR_RESPONSE OBJECTION_TO_STRIKE_OFF ORDINARY_BULK_OBJECTIONS
do
  reportStuckTextMessages ${MESSAGE_TYPE} "${TMP_DIR}" >> ${TMP_REPORT_FILE}
done

# Count lines in the report file to see if we need to send an alert
LINE_COUNT=$(wc -l ${TMP_REPORT_FILE} | awk '{print $1}')
if [[ ${LINE_COUNT} -eq 0 ]]
then
  echo "No stuck messages"
  exit 0
fi

# Now we need to email out the report
email_report_f ${EMAIL_ADDRESS_CSI} "Following JMS messages are stuck in ChipsGenericErrorQueue $(date)" "$(cat ${TMP_REPORT_FILE})"

# Clean up
rm -f ${TMP_EMAIL_FILE}
rm -f ${TMP_REPORT_FILE}
rm -f ${TMP_LIST_FILE}
rm -rf ${TMP_DIR}
