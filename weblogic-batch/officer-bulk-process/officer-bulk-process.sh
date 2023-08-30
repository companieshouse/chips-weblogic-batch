#!/bin/bash

function check_error_lock_file {
        if [ -f /apps/oracle/officer-bulk-process/OFFICER_LOCK_FILE_ALERT ]; then
                f_logError "OFFICER_LOCK_FILE_ALERT exists. Previous run failed."
                email_CHAPS_group_f " $(pwd)/$(basename $0): OFFICER_LOCK_FILE_ALERT exists. Previous run failed."
                exit 1
        fi
}

function set_error_lock_file {
        touch /apps/oracle/officer-bulk-process/OFFICER_LOCK_FILE_ALERT
}

function remove_running_lock_file {
        rm /apps/oracle/officer-bulk-process/OFFICER_RUNNING
}

function set_running_lock_file {
        touch /apps/oracle/officer-bulk-process/OFFICER_RUNNING
}

function check_running_lock_file {
        if [ -f /apps/oracle/officer-bulk-process/OFFICER_RUNNING ]; then
                f_logError "OFFICER_RUNNING lock file exists. Officer already running."
                email_CHAPS_group_f " $(pwd)/$(basename $0): OFFICER_RUNNING lock file exists. Officer already running."
                exit 1
        fi
}

cd /apps/oracle/officer-bulk-process

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst <officer-poller.properties.template >officer-poller.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs/xstream.jar:/apps/oracle/libs/cglib-nodep.jar:/apps/oracle/libs/joda-time.jar:/apps/oracle/libs/commons-lang.jar:/apps/oracle/libs/ojdbc8.jar:/apps/oracle/libs/wlfullclient.jar:/apps/oracle/libs/spring.jar:/apps/oracle/libs/log4j-core.jar:/apps/oracle/libs/log4j-api.jar:/apps/oracle/libs/log4j-1.2-api.jar:/apps/oracle/officer-bulk-process/officer-bulk-process.jar

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/officer-bulk-process
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-officer-bulk-process-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >>${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

if [[ $# > 1 ]]; then
        f_logError "$(date) Failed to start officer-bulk-process: Too many parameters, options are 123 | 2 | 3 | 23"
        exit 1
fi

# default to running all three stages
RUN_STAGE_ONE="true"
RUN_STAGE_TWO="true"
RUN_STAGE_THREE="true"

case $1 in
"123" | "") ;;
"2")
        RUN_STAGE_ONE="false"
        RUN_STAGE_THREE="false"
        ;;
"3")
        RUN_STAGE_ONE="false"
        RUN_STAGE_TWO="false"
        ;;
"23")
        RUN_STAGE_ONE="false"
        ;;
*)
        f_logError "Failed to start officer-bulk-process: Unknown parameter value, options are 123 | 2 | 3 | 23"
        exit 1
        ;;
esac

LOG_STRING="Starting officer-bulk-process: Running stage(s)"
if [[ ${RUN_STAGE_ONE} == "true" ]]; then LOG_STRING+=" ONE"; fi
if [[ ${RUN_STAGE_TWO} == "true" ]]; then LOG_STRING+=" TWO"; fi
if [[ ${RUN_STAGE_THREE} == "true" ]]; then LOG_STRING+=" THREE"; fi
f_logInfo "${LOG_STRING}"

## Check if previous run has failed or job already running, exit and alert
check_error_lock_file
check_running_lock_file

## Set running file to prevent duplicate running
set_running_lock_file

## REAL WORK BEGINS

if [[ ${RUN_STAGE_ONE} == "true" ]]; then

        ## Check to make sure we did not time out on previous PUBLISH stage i.e. are there any -10000 WORK_ITEM_REFERENCE
        f_logInfo "Running check to make sure we did not time out on previous PUBLISH stage"
        ./check-officer-publish-finished.command

        if [ $? -gt 0 ]; then
                f_logError "Non-zero exit code for check-officer-publish-finished.command"
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-officer-publish-finished.command. "
                exit 1
        fi

        f_logInfo "Running reset Batch process parameters"
        ./reset-director-bpp.command

        if [ $? -gt 0 ]; then
                f_logError "Non-zero exit code for reset-director-bpp.command "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for reset-director-bpp.command. "
                exit 1
        fi

        ## Check that BPP timestamp order is as expected for EVENT stage
        ./check-bpp-timestamps-order.command "BULK_EVENT_TMSP BULK_MERGE_TMSP BULK_PUB_TMSP"

        if [ $? -gt 0 ]; then
                f_logError "Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                exit 1
        fi

        ## Run FIRST stage of Officer job - EVENT
        f_logInfo "Run FIRST stage of Officer job - EVENT  - normal mode"

        /usr/java/jdk-8/bin/java -Din=officer-bulk-process -cp $CLASSPATH -Dlog4j.configurationFile=log4j2.xml \
                uk.gov.companieshouse.officerbulkprocess.OfficerDetailEventPoller normal ${JMS_JNDIPROVIDERURL} bulk-officer.xml

        if [ $? -gt 0 ]; then
                f_logError "Non-zero exit code for FIRST stage officer java execution"
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for FIRST stage officer java execution. "
                exit 1
        fi

        f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        f_logInfo "Zero return code for FIRST stage of Officer job - EVENT. Exit probably successful"
        f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

        if [[ ${RUN_STAGE_TWO} == "true" || ${RUN_STAGE_THREE} == "true" ]]; then
                ## Sleep after job returns as processing is still going on in server
                sleep 1800 # 30 min
        fi

fi

if [[ ${RUN_STAGE_TWO} == "true" ]]; then

        ## Check that BPP timestamp order is as expected for MERGE stage
        ./check-bpp-timestamps-order.command "BULK_MERGE_TMSP BULK_PUB_TMSP BULK_EVENT_TMSP"

        if [ $? -gt 0 ]; then
                f_logError "Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                exit 1
        fi

        ## Run SECOND stage of Officer job - MERGE
        f_logInfo "Run SECOND stage of Officer job - MERGE - catchup mode"
        /usr/java/jdk-8/bin/java -Din=officer-bulk-process -cp $CLASSPATH -Dlog4j.configurationFile=log4j2.xml \
                uk.gov.companieshouse.officerbulkprocess.OfficerDetailEventPoller catchup ${JMS_JNDIPROVIDERURL} bulk-officer.xml

        if [ $? -gt 0 ]; then
                f_logError "Non-zero exit code for SECOND stage officer java execution"
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for SECOND stage officer java execution. "
                exit 1
        fi

        f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        f_logInfo "Zero return code for SECOND stage of Officer job - MERGE. Exit probably successful"
        f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

        if [[ ${RUN_STAGE_THREE} == "true" ]]; then
                ## Sleep after job returns as processing is still going on in server
                sleep 1800 # 30 min
        fi

fi

if [[ ${RUN_STAGE_THREE} == "true" ]]; then

        ## Check that BPP timestamp order is as expected for PUBLISH stage
        ./check-bpp-timestamps-order.command "BULK_PUB_TMSP BULK_EVENT_TMSP BULK_MERGE_TMSP"

        if [ $? -gt 0 ]; then
                f_logError "Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                exit 1
        fi

        ## Check to make sure we cleared OFFICER_EVENT_MATCH on previous MERGE stage i.e. are there any rows left in OFFICER_EVENT_MATCH
        f_logInfo "Running check to make sure we did finish MERGE stage"
        ./check-officer-merge-finished.command

        if [ $? -gt 0 ]; then
                f_logError "Non-zero exit code for check-officer-merge-finished.command "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-officer-merge-finished.command. "
                exit 1
        fi

        ## Run THIRD stage of Officer job - PUBLISH
        f_logInfo "Run THIRD stage of Officer job - PUBLISH - catchup mode"
        /usr/java/jdk-8/bin/java -Din=officer-bulk-process -cp $CLASSPATH -Dlog4j.configurationFile=log4j2.xml \
                uk.gov.companieshouse.officerbulkprocess.OfficerDetailEventPoller catchup ${JMS_JNDIPROVIDERURL} bulk-officer.xml

        if [ $? -gt 0 ]; then
                f_logError "Non-zero exit code for THIRD stage officer java execution"
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for officer java execution. "
                exit 1
        fi

        f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        f_logInfo "Zero return code for THIRD stage of Officer job - PUBLISH. Exit probably successful"
        f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

fi

## Remove running lock file
remove_running_lock_file
## mail CSI on job completion and include what day it processed 
email_report_f "${EMAIL_ADDRESS_CSI}" "Bulk Officer finished $(date "+%a %b %d %T")" "$(grep BULK_EVENT_TMSP "${LOG_FILE}" |tail -1)"

f_logInfo "Ending officer-bulk-process"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
