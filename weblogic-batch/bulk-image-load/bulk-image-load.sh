#!/bin/bash

cd /apps/oracle/bulk-image-load

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < bulk-image-load.properties.template > bulk-image-load.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs/wlfullclient.jar:/apps/oracle/libs/log4j-1.2-api.jar:/apps/oracle/libs/log4j-api.jar:/apps/oracle/libs/log4j-core.jar:/apps/oracle/bulk-image-load/bulk-image-load.jar

# Set up mail config for msmtp & load alerting functions
envsubst < ../.msmtprc.template > ../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/bulk-image-load
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-bulk-image-load-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting bulk-image-load"

f_logInfo "Checking that bulk-image-load is not already running"
../scripts/check-for-jms-message.sh ${JMS_BULKIMAGELOADQUEUE}
if [ $? -gt 0 ]; then
        f_logError "bulk-image-load may be already running or connection error.  Please investigate."
        patrol_log_alert_chaps_f " `pwd`/`basename $0`:  bulk-image-load may be already running or connection error.  Please investigate."
        exit 1
fi

f_logInfo "Count how many rows are in IMAGE_API_IN before job runs"
./count_image_api_in_table.command

/usr/java/jdk-8/bin/java -Din=bulk-image-load -cp $CLASSPATH -Dlog4j.configuration=log4j.xml uk.gov.companieshouse.bulkimageload.BulkImageLoadRunner bulk-image-load.properties
if [ $? -gt 0 ]; then
        f_logError "Non-zero exit code for bulk-image-load java execution"
        exit 1
fi

f_logInfo "Ending bulk-image-load"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
