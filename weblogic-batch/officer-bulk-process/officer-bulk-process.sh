#!/bin/bash

function check_error_lock_file {
        if [ -f /apps/oracle/officer-bulk-process/OFFICER_LOCK_FILE_ALERT ]; then
                echo "OFFICER_LOCK_FILE_ALERT exists. Previous run failed."
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
                echo "OFFICER_RUNNING lock file exists. Officer already running."
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

exec >>${LOG_FILE} 2>&1

echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if [[ $# > 1 ]]; then
        echo "$(date) Failed to start officer-bulk-process: Too many parameters, options are 123 | 2 | 3 | 23"
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
        echo "$(date) Failed to start officer-bulk-process: Unknown parameter value, options are 123 | 2 | 3 | 23"
        exit 1
        ;;
esac

echo -n "$(date) Starting officer-bulk-process: Running stage(s) "
if [[ ${RUN_STAGE_ONE} == "true" ]]; then echo -n "ONE "; fi
if [[ ${RUN_STAGE_TWO} == "true" ]]; then echo -n "TWO "; fi
if [[ ${RUN_STAGE_THREE} == "true" ]]; then echo -n "THREE "; fi
echo

## Check if previous run has failed or job already running, exit and alert
check_error_lock_file
check_running_lock_file

## Set running file to prevent duplicate running
set_running_lock_file

## Check to make sure we did not time out on previous PUBLISH stage i.e. are there any -10000 WORK_ITEM_REFERENCE
echo Running check to make sure we did not time out on previous PUBLISH stage
./check-officer-publish-finished.command

if [ $? -gt 0 ]; then
        echo "Non-zero exit code for check-officer-publish-finished.command"
        remove_running_lock_file
        set_error_lock_file
        email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-officer-publish-finished.command. "
        exit 1
fi

## REAL WORK BEGINS

if [[ ${RUN_STAGE_ONE} == "true" ]]; then
        echo Running reset Batch process parameters
        ./reset-director-bpp.command

        if [ $? -gt 0 ]; then
                echo "Non-zero exit code for reset-director-bpp.command "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for reset-director-bpp.command. "
                exit 1
        fi

        ## Check that BPP timestamp order is as expected for EVENT stage
        ./check-bpp-timestamps-order.command "BULK_EVENT_TMSP BULK_MERGE_TMSP BULK_PUB_TMSP"

        if [ $? -gt 0 ]; then
                echo "Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                exit 1
        fi

        ## Run FIRST stage of Officer job - EVENT
        echo "Run FIRST stage of Officer job - EVENT  - normal mode"

        /usr/java/jdk-8/bin/java -Din=officer-bulk-process -cp $CLASSPATH -Dlog4j.configurationFile=log4j2.xml \
                uk.gov.companieshouse.officerbulkprocess.OfficerDetailEventPoller normal ${JMS_JNDIPROVIDERURL} bulk-officer.xml

        if [ $? -gt 0 ]; then
                echo "Non-zero exit code for FIRST stage officer java execution"
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for FIRST stage officer java execution. "
                exit 1
        fi

        echo
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo "Zero return code for FIRST stage of Officer job - EVENT. Exit probably successful"
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo

        if [[ ${RUN_STAGE_TWO} == "true" || ${RUN_STAGE_THREE} == "true" ]]; then
                ## Sleep after job returns as processing is still going on in server
                sleep 1800 # 30 min
        fi

fi

if [[ ${RUN_STAGE_TWO} == "true" ]]; then

        ## Check that BPP timestamp order is as expected for MERGE stage
        ./check-bpp-timestamps-order.command "BULK_MERGE_TMSP BULK_PUB_TMSP BULK_EVENT_TMSP"

        if [ $? -gt 0 ]; then
                echo "Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                exit 1
        fi

        ## Run SECOND stage of Officer job - MERGE
        echo "Run SECOND stage of Officer job - MERGE - catchup mode"
        /usr/java/jdk-8/bin/java -Din=officer-bulk-process -cp $CLASSPATH -Dlog4j.configurationFile=log4j2.xml \
                uk.gov.companieshouse.officerbulkprocess.OfficerDetailEventPoller catchup ${JMS_JNDIPROVIDERURL} bulk-officer.xml

        if [ $? -gt 0 ]; then
                echo "Non-zero exit code for SECOND stage officer java execution"
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for SECOND stage officer java execution. "
                exit 1
        fi

        echo
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo "Zero return code for SECOND stage of Officer job - MERGE. Exit probably successful"
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo

        if [[ ${RUN_STAGE_THREE} == "true" ]]; then
                ## Sleep after job returns as processing is still going on in server
                sleep 1800 # 30 min
        fi

fi

if [[ ${RUN_STAGE_THREE} == "true" ]]; then

        ## Check that BPP timestamp order is as expected for PUBLISH stage
        ./check-bpp-timestamps-order.command "BULK_PUB_TMSP BULK_EVENT_TMSP BULK_MERGE_TMSP"

        if [ $? -gt 0 ]; then
                echo "Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-bpp-timestamps-order.command - BPP timestamp order not as expected "
                exit 1
        fi

        ## Check to make sure we cleared OFFICER_EVENT_MATCH on previous MERGE stage i.e. are there any rows left in OFFICER_EVENT_MATCH
        echo Running check to make sure we did finish MERGE stage
        ./check-officer-merge-finished.command

        if [ $? -gt 0 ]; then
                echo "Non-zero exit code for check-officer-merge-finished.command "
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for check-officer-merge-finished.command. "
                exit 1
        fi

        ## Run THIRD stage of Officer job - PUBLISH
        echo "Run THIRD stage of Officer job - PUBLISH - catchup mode"
        /usr/java/jdk-8/bin/java -Din=officer-bulk-process -cp $CLASSPATH -Dlog4j.configurationFile=log4j2.xml \
                uk.gov.companieshouse.officerbulkprocess.OfficerDetailEventPoller catchup ${JMS_JNDIPROVIDERURL} bulk-officer.xml

        if [ $? -gt 0 ]; then
                echo "Non-zero exit code for THIRD stage officer java execution"
                remove_running_lock_file
                set_error_lock_file
                email_CHAPS_group_f " $(pwd)/$(basename $0): Non-zero exit code for officer java execution. "
                exit 1
        fi

        echo
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo "Zero return code for THIRD stage of Officer job - PUBLISH. Exit probably successful"
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo

fi

## Remove running lock file
remove_running_lock_file

echo $(date) Ending officer-bulk-process
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
