#!/bin/bash

# =============================================================================
#
#  This script is used to report on JMS messages in the AcspUsersErrorQueue    
#  across all WebLogic servers.
#
#  An optional parameter may be supplied which sets the email address(es) to send
#  the report to.  This should be a comma separated list of email recipients without spaces.
# 
#  If no parameter is supplied, the script uses an optional STUCK_DOCS_REPORT_EMAIL_ADDRESSES
#  environment variable to determine which email addresses to send the report to.
#  This should be a comma separated list of email recipients without spaces.
#
#  If the STUCK_DOCS_REPORT_EMAIL_ADDRESSES environment variable is not set, the report
#  will be sent to just the email address in the EMAIL_ADDRESS_CSI environment variable.
#
# =============================================================================

parseData() {
  JMS_MESSAGE_ID=$(echo "$1" | grep -oP 'ID:<\K[^>]+')
  FORM_BARCODE=$(echo "$1" | grep -oP 'barcode=\K[^,]+')
  USER_ACCOUNT_ID=$(echo "$1" | grep -oP 'userAccountId=\K[^,]+')
  ACSP_NUMBER=$(echo "$1" | grep -oP 'acspNumber=\K[^]]+')
}

parseDataAndWrite () {
  parseData "$1"
  echo "${FORM_BARCODE}|${USER_ACCOUNT_ID}|${ACSP_NUMBER}|${JMS_MESSAGE_ID}" >> $2
}

smallBanner() {
 DASHES="------------------------------------------------------------------------------------"
 echo
 echo ${DASHES}
 echo $1
 echo ${DASHES}
 echo
}

cd /apps/oracle/admin/jms

# load variables created from setCron script
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst </apps/oracle/.msmtprc.template >/apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

# set up logging
LOGS_DIR=/apps/oracle/logs/jms
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-report-acsp-stuck-submissions-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec > >(tee "${LOG_FILE}") 2>&1

TMP_LIST_FILE=list-acsp-all-jms.output
TMP_METADATA_FILE=acsp-extracted-metadata.tmp

# Extract a list of acsp messages from all jms servers
./list-all-jms.sh uk.gov.ch.chips.jms.AcspUsersErrorQueue | grep BindUserToAcspMessage > ${TMP_LIST_FILE}

COUNT=$(wc -l < ${TMP_LIST_FILE})
echo "Count :$COUNT"
rm -f ${TMP_METADATA_FILE} 
if [[ ${COUNT} -gt 0 ]]
then
  
   while read -r LINE; do
 parseDataAndWrite "${LINE}" ${TMP_METADATA_FILE}

  done <${TMP_LIST_FILE}
 fi

TMP_REPORT_FILE=acsp-report.tmp

COUNT=$(wc -l < ${TMP_METADATA_FILE})
if [[ ${COUNT} -gt 0 ]]
then
  {
  smallBanner "ACSP docs"

  echo "  Count :$COUNT"

  echo
  cat ${TMP_METADATA_FILE} | sed 's/[|]*|\(.*\)/  \1/' | sed 's/|/    /g' | uniq
  echo

  } > ${TMP_REPORT_FILE}

  # Now we need to email out the report
  STUCK_DOCS_REPORT_EMAIL_ADDRESSES=${1:-${STUCK_DOCS_REPORT_EMAIL_ADDRESSES}}
  EMAIL_ADDRESSES=${STUCK_DOCS_REPORT_EMAIL_ADDRESSES:-${EMAIL_ADDRESS_CSI}}
  email_report_f "${EMAIL_ADDRESSES}" "Following ACSP docs currently stuck ${DATE}" "$(cat ${TMP_REPORT_FILE})"

  # Clean up
  rm -f ${TMP_REPORT_FILE}

fi


