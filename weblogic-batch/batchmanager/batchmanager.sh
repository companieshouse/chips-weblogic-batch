#!/bin/bash

cd /apps/oracle/batchmanager

# load variables created from setCron script
source /apps/oracle/env.variables
# create properties file and substitutes values
envsubst < batchmanager.properties.template > chips_batchmanager.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs/wlthint3client.jar:/apps/oracle/libs/spring.jar:/apps/oracle/libs/log4j-1.2-api.jar:/apps/oracle/libs/log4j-api.jar:/apps/oracle/libs/log4j-core.jar:/apps/oracle/batchmanager/batch-manager.jar
# set up logging
LOGS_DIR=../logs/batchmanager
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-batchmanager-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting BatchManager"

/usr/java/jdk/bin/java -Din=Batchmanager -cp $CLASSPATH uk.gov.companieshouse.chips.standalone.batch.SpringBatchManager
if [ $? -gt 0 ]; then
        f_logError "Non-zero exit code for batchmanager java execution"
        exit 1
fi

f_logInfo "Ending BatchManager"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
