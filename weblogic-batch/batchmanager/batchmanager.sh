#!/bin/bash

cd /apps/oracle/batchmanager

# load variables created from setCron script
source /apps/oracle/env.variables

# create properties file and substitutes values
envsubst < batchmanager.properties.template > chips_batchmanager.properties

# Updated CLASSPATH - batch-manager.jar and other dependencies
CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/spring-core-4.3.30.RELEASE.jar:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs/spring-beans-4.3.30.RELEASE.jar:/apps/oracle/libs/spring-context-4.3.30.RELEASE.jar:/apps/oracle/libs/spring-jms-4.3.30.RELEASE.jar:/apps/oracle/libs/spring-aop-4.3.30.RELEASE.jar:/apps/oracle/libs/spring-expression-4.3.30.RELEASE.jar:/apps/oracle/libs/javax.jms-api-2.0.1.jar:/apps/oracle/libs/log4j-api-2.25.3.jar:/apps/oracle/libs/log4j-core-2.25.3.jar:/apps/oracle/libs/log4j-jcl-2.25.3.jar:/apps/oracle/libs/wlthint3client-14.1.2.0.jar:/apps/oracle/batchmanager/batch-manager.jar

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
