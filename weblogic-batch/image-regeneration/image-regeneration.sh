#!/bin/bash

cd /apps/oracle/image-regeneration

# load variables created from setCron script
source /apps/oracle/env.variables

LIBS_DIR=/apps/oracle/libs
CLASSPATH=${CLASSPATH}:.:${LIBS_DIR}/log4j-api.jar:${LIBS_DIR}/log4j-core.jar:${LIBS_DIR}/wlfullclient.jar:/apps/oracle/image-regeneration/image-regeneration.jar

# set up logging
LOGS_DIR=../logs/image-regeneration
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-image-regeneration-$(date +'%Y-%m-%d_%H-%M-%S').log"

exec >> ${LOG_FILE} 2>&1

echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo `date --iso-8601=seconds` Starting image-regeneration

IMAGE_REGENERATE_CLIENT_NAME=uk.gov.companieshouse.imaging.ImagingRegenerateClient
#IMAGE_REGENERATE_CLIENT_NAME=uk.gov.companieshouse.imaging.FESImagingRegenerateClient


/usr/java/jdk-8/bin/java -Din=image-regeneration -cp ${CLASSPATH} -Dlog4j.configurationFile=log4j2.xml ${IMAGE_REGENERATE_CLIENT_NAME} ${JMS_JNDIPROVIDERURL} transaction_ids.txt ${WEBLOGIC_ADMIN_USERNAME} ${ADMIN_PASSWORD}


if [ $? -gt 0 ]; then
        echo "Non-zero exit code for image-regeneration java execution"
        exit 1
fi

echo `date --iso-8601=seconds` Ending image-regeneration
echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
