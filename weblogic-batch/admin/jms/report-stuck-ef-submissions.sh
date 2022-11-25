#!/bin/bash

# =============================================================================
#
#  This script is used to report on JMS messages in the EfilingRequestErrorQueue    
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

parseXML() {
  BARCODE=$(xmlstarlet sel -t -v "//barcode" $1)
  FORM_TYPE=$(xmlstarlet sel -t -v "//form/@type" $1)
  CORPORATE_BODY_NAME=$(xmlstarlet sel -t -v "//corporateBodyName[1]" $1)
  INCORPORATION_NUMBER=$(xmlstarlet sel -t -v "//incorporationNumber" $1)
  METHOD=$(xmlstarlet sel -t -v "//method" $1)
}

parseAndWriteMetaData () {
  parseXML $1
  echo "${FORM_TYPE}|${BARCODE}|${INCORPORATION_NUMBER}|${METHOD}|${CORPORATE_BODY_NAME}" >> $2
  rm -f $1
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
envsubst <../../.msmtprc.template >../../.msmtprc
source ../../scripts/alert_functions

# set up logging
LOGS_DIR=../../logs/jms
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-report-stuck-ef-submissions-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec > >(tee "${LOG_FILE}") 2>&1

TMP_LIST_FILE=list-all-jms.output
TMP_METADATA_FILE=extracted-metadata.tmp
TMP_XML_FILE=xml.tmp

# Extract a list of submission xml from all jms servers
./list-all-jms.sh uk.gov.ch.chips.jms.EfilingRequestErrorQueue > ${TMP_LIST_FILE}

# Tidy up the extracted list so that it just contains xml without any attachment data
sed -i -n '/^<?xml/,/<\/form>/p' ${TMP_LIST_FILE}
sed -i '/<attachment>/,/<\/attachment>/d' ${TMP_LIST_FILE}

# Check if there is any xml in TMP_LIST_FILE - if not then we can exit as no stuck docs
grep -q xml ${TMP_LIST_FILE}
if [[ $? -gt 0 ]]
then
  f_logInfo "No stuck documents"
  exit 0
fi

# Extract data from the list of stuck docs in TMP_LIST_FILE, one document at a time
rm -f ${TMP_XML_FILE} ${TMP_METADATA_FILE}
while read -r LINE; do
  if [[ ${LINE} =~ ^\<\?xml ]]
  then
    # new xml found - process previously saved xml if present
    if [[ -f ${TMP_XML_FILE} ]]
    then
      parseAndWriteMetaData ${TMP_XML_FILE} ${TMP_METADATA_FILE}
    fi
  fi
  echo "${LINE}" >> ${TMP_XML_FILE}

done <${TMP_LIST_FILE}
# Process the last submission as we have reached the end of TMP_LIST_FILE
parseAndWriteMetaData ${TMP_XML_FILE} ${TMP_METADATA_FILE}

# Now we have our metadata, we need to generate a report

TMP_REPORT_FILE=report.tmp
DATE=$(date)
echo "Snapshot of docs in EfilingRequestErrorQueue at ${DATE}. CSI will fix these and push these to QH queues ASAP.\n" > ${TMP_REPORT_FILE}

COUNT=$(grep -c -v scan ${TMP_METADATA_FILE})
if [[ ${COUNT} -gt 0 ]]
then
  { 
  smallBanner "EF/CHS docs"

  echo "  Cnt | Type"
  grep -v scan ${TMP_METADATA_FILE} | sort | awk -F\| '{print $1}' | uniq -c

  echo
  IFS=$'\n'
  for DOC_TYPE in $(grep -v scan ${TMP_METADATA_FILE} | sort | awk -F\| '{print $1}' | uniq)
  do
    echo "  ${DOC_TYPE}:"
    grep -v scan ${TMP_METADATA_FILE} | grep -E "^${DOC_TYPE}" | sed 's/[^|]*|\(.*\)/  \1/' | sed 's/|/    /g'
    echo
  done
  } >> ${TMP_REPORT_FILE}
fi


COUNT=$(grep -c scan ${TMP_METADATA_FILE})
if [[ ${COUNT} -gt 0 ]]
then
  {
  smallBanner "FES/Scanned docs"

  echo "  Cnt | Type"
  grep scan ${TMP_METADATA_FILE} | sort | awk -F\| '{print $1}' | uniq -c

  echo
  IFS=$'\n'
  for DOC_TYPE in $(grep scan ${TMP_METADATA_FILE} | sort | awk -F\| '{print $1}' | uniq)
  do
    echo "  ${DOC_TYPE}:"
    grep scan ${TMP_METADATA_FILE} | grep -E "^${DOC_TYPE}" | sed 's/[^|]*|\(.*\)/  \1/' | sed 's/|/    /g'
    echo
  done
  } >> ${TMP_REPORT_FILE}
fi

# Now we need to email out the report
STUCK_DOCS_REPORT_EMAIL_ADDRESSES=${1:-${STUCK_DOCS_REPORT_EMAIL_ADDRESSES}}
EMAIL_ADDRESSES=${STUCK_DOCS_REPORT_EMAIL_ADDRESSES:-${EMAIL_ADDRESS_CSI}}
email_report_f ${EMAIL_ADDRESSES} "Following CLOUD EF or FES/Scanned docs currently stuck ${DATE}" "$(cat ${TMP_REPORT_FILE})"

# Clean up
rm -f ${TMP_EMAIL_FILE}
rm -f ${TMP_REPORT_FILE}

