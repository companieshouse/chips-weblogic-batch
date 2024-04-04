#!/bin/bash

# Script to transfer the doc1 letters to our third-party printing company, currently APS
# Author: ijenkins
# Date: April 2021
# If called with no parameters, it will attempt to copy all files as defined in the
# $letter_types variable in .process-compliance.properties
# If called with one parameter it will attempt to tranfer specific letter types
# Examples:
#    send-letters-to-print-provider.sh
#    send-letters-to-print-provider.sh CHSHUREP

cd /apps/oracle/send-letters

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

# Setting up standard logging here, but task scripts also log separately using tee to duplicate the output
# set up logging
LOGS_DIR=../logs/send-letters
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-send-letters-to-print-provider-$(date +'%Y-%m-%d').log"
source /apps/oracle/scripts/logging_functions

exec >> "${LOG_FILE}" 2>&1


f_logInfo "Starting send-letters-to-print-provider"

this_progname="$(basename $BASH_SOURCE)"

if [[ $# -gt 1 ]]; then
    f_logInfo "Usage:"
    f_logInfo "send-letters-to-print-provider.sh [optional_letter_type]"
    exit 0
fi

failed="false"
failed_files=""
server="$HOSTNAME"
is_archive="false"

if [[ -z ${PRINT_PROVIDER_LETTER_TYPES} ]]; then
  f_logError "PRINT_PROVIDER_LETTER_TYPES not set - please edit properties"  ; exit 1
fi

if [[ -z ${LETTER_OUTPUT_FILES_PREVIOUS_LOCATION} ]]; then
  f_logError "LETTER_OUTPUT_FILES_PREVIOUS_LOCATION not set - please edit properties"  ; exit 1
fi

if [[ -z ${LETTER_OUTPUT_FILES_LOCATION} ]]; then
  f_logError "LETTER_OUTPUT_FILES_LOCATION not set - please edit properties"  ; exit 1
fi

if [[ -z ${LETTER_OUTPUT_FILES_LOCATION} ]]; then
  f_logError "LETTER_OUTPUT_FILES_LOCATION not set - please edit properties"  ; exit 1
fi

if [ -z "$LETTER_OUTPUT_FILES_ARCHIVE_LOCATION" ]; then
    f_logInfo "No LETTER_OUTPUT_FILES_ARCHIVE_LOCATION variable defined so skipping the archiving the files"
else 
    archive_dir="$LETTER_OUTPUT_FILES_ARCHIVE_LOCATION"
    is_archive="true"
    mkdir -p $archive_dir
fi


letter_types="${PRINT_PROVIDER_LETTER_TYPES}"

if [[ $1 != "" ]]; then
    f_logInfo "$1 requested"
    letter_types=$1
fi

previous_files_dir="$LETTER_OUTPUT_FILES_PREVIOUS_LOCATION"

f_logInfo "LETTER_OUTPUT_FILES_PREVIOUS_LOCATION : $LETTER_OUTPUT_FILES_PREVIOUS_LOCATION"
f_logInfo "LETTER_OUTPUT_FILES_LOCATION : $LETTER_OUTPUT_FILES_LOCATION"
f_logInfo "LETTER_OUTPUT_FILES_ARCHIVE_LOCATION : $LETTER_OUTPUT_FILES_ARCHIVE_LOCATION"
f_logInfo "PRINT_PROVIDER_SERVER_FILE_PATH : $PRINT_PROVIDER_SERVER_FILE_PATH"

mkdir -p $LETTER_OUTPUT_FILES_PREVIOUS_LOCATION
mkdir -p $LETTER_OUTPUT_FILES_LOCATION

if [ ! -f ${PRINT_PROVIDER_SERVER_KEY_FILE_PATH} ]; then
  cp /apps/oracle/config/$PRINT_PROVIDER_SERVER_KEY_FILE_NAME ${PRINT_PROVIDER_SERVER_KEY_FILE_PATH}
  chmod 0600 ${PRINT_PROVIDER_SERVER_KEY_FILE_PATH}
fi

for i in $letter_types
do
    if grep -i -q "count" <<< "$i"; then
        latest_letter_file=`ls -tr "$LETTER_OUTPUT_FILES_LOCATION$PRINT_PROVIDER_LETTER_COUNT_FILE" 2>/dev/null | tail -1`
    else
        latest_letter_file=`ls -tr "$LETTER_OUTPUT_FILES_LOCATION"*-$i.*dat.afp 2>/dev/null | tail -1`
    fi

    if [[ $latest_letter_file == "" ]] ;
    then
    #    echo "No $i file to send, continuing"
        continue
    fi

    f_logInfo "$latest_letter_file found"

    previous_file=$previous_files_dir$i
    f_logInfo "previous_file is $previous_file"

    if  cmp -s $latest_letter_file $previous_file
     then
        f_logWarn "duplicate_file_found $latest_letter_file"
        f_logWarn "$i file has identical contents to previous file, so file not sent to $PRINT_PROVIDER_NAME"
        email_report_f "${EMAIL_ADDRESS_CSI}" "Identical $i file detected" "$this_progname running on $server has determined that the latest $i file is: $latest_letter_file, " \
        " but this file has previously been sent to $PRINT_PROVIDER_NAME"
        continue
    fi

    f_logInfo "latest_letter_file is $latest_letter_file"

    f_logInfo "calling sftp"
    printf "%s\n" "lcd $LETTER_OUTPUT_FILES_LOCATION" "put $latest_letter_file" "ls -l" | sftp -o StrictHostKeychecking=no -o UserKnownHostsFile=/dev/null -i $PRINT_PROVIDER_SERVER_KEY_FILE_PATH -b - $PRINT_PROVIDER_SERVER_USER_NAME@$PRINT_PROVIDER_SERVER_NAME:$PRINT_PROVIDER_SERVER_FILE_PATH 
    rc=$?
    if [[ rc -eq 0 ]] ;
    then
        f_logInfo "sftp of $latest_letter_file succeeded at `date +"%H:%M:%S on %d/%m/%Y"`"
        cp $latest_letter_file $previous_files_dir$i
        if [ $is_archive = "true" ] ; then
            f_logInfo "Moving $latest_letter_file to archive"
            mv $latest_letter_file $archive_dir
            rc=$?
            if [[ rc -ne 0 ]] ; then
                f_logInfo "Failed to move $latest_letter_file to archive"
                email_report_f "${EMAIL_ADDRESS_CSI}" "Failed to move $latest_letter_file to archive" "$this_progname running on $server has failed to move $latest_letter_file " \
                "to $archive_dir"
            fi
        fi
    else
        failed="true"
        failed_files="$failed_files $latest_letter_file\n"
    fi

done


if [ $failed = "true" ] ; then
    f_logError "sftp of letter_file(s) failed at `date +"%H:%M:%S on %d/%m/%Y"`"
    f_logInfo "failed file list is: $failed_files"
    email_report_f "${EMAIL_ADDRESS_CSI}" "Failed to sftp letter file(s) to $PRINT_PROVIDER_NAME" "$this_progname running on $server has failed to send the following files:\n$failed_files "\
        "to $PRINT_PROVIDER_NAME via sftp"
fi

f_logInfo "Finished at `date +"%H:%M:%S on %d/%m/%Y"`"
