#!/bin/bash

cd /apps/oracle/batchmanager

source /apps/oracle/env.variables

envsubst < batchmanager.properties.template > chips_batchmanager.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs/wlthint3client.jar:/apps/oracle/libs/spring.jar:/apps/oracle/libs/log4j.jar:/apps/oracle/batchmanager/batch-manager.jar

LOGS_DIR=../logs/batchmanager
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-batchmanager-$(date +'%Y-%m-%d_%H-%M-%S').log"

exec >> ${LOG_FILE} 2>&1

echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo `date` Starting BatchManager

/usr/java/jdk-8/bin/java -Din=Batchmanager -cp $CLASSPATH uk.gov.companieshouse.chips.standalone.batch.SpringBatchManager
if [ $? -gt 0 ]; then
        echo "Non-zero exit code for batchmanager java execution"
        exit 1
fi

echo `date` Ending BatchManager
echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
