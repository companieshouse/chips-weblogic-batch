#!/bin/bash

cd /apps/oracle/psc-pursuit-trigger

# load variables created from setCron script
source /apps/oracle/env.variables
# create properties file and substitutes values
envsubst < psc-pursuit-trigger.properties.template > psc-pursuit-trigger.properties

CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/commons-logging.jar:/apps/oracle/libs/ojdbc8.jar:/apps/oracle/libs/log4j.jar:/apps/oracle/psc-pursuit-trigger/psc-pursuit-trigger.jar

# set up logging
LOGS_DIR=../logs/psc-pursuit-trigger
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-psc-pursuit-trigger-$(date +'%Y-%m-%d_%H-%M-%S').log"

exec >> ${LOG_FILE} 2>&1

echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo `date` Starting psc-pursuit-trigger

/usr/java/jdk-8/bin/java -Din=psc-pursuit-trigger -cp $CLASSPATH -Dlog4j.configuration=log4j.xml uk.gov.companieshouse.psc.pursuit.trigger.PscPursuitTrigger psc-pursuit-trigger.properties
if [ $? -gt 0 ]; then
        echo "Non-zero exit code for psc-pursuit-trigger java execution"
        exit 1
fi

echo `date` Ending psc-pursuit-trigger
echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
