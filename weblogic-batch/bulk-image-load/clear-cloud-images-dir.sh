#!/bin/bash

# Description   : Monitors CloudImages directory for stale docs
#                 known issue file in dir is corrupt we need to delete the file and resend to CHS

cd /apps/oracle/bulk-image-load

# load variables created from setCron script
source /apps/oracle/env.variables

CLOUD_IMAGES_DIR=../chipsdomain/CloudImages
STUCK_FILE_LIST=/tmp/monitor_cloud_images_msg

# set up logging
LOGS_DIR=../logs/bulk-image-load
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-clear-cloud-images-dir-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> ${LOG_FILE} 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting clear-cloud-images-dir"

find $CLOUD_IMAGES_DIR/ -type f -mtime +0.5 > $STUCK_FILE_LIST

f_logInfo "Deleting the following docs that are stuck in CloudImages on $HOSTNAME `date +%d/%m/%y`"

if [ -s $STUCK_FILE_LIST ]
then
  for line in `cat $STUCK_FILE_LIST`
  do
     f_logInfo "removing file $line"
     rm $line
  done
fi

f_logInfo "Ending clear-cloud-images-dir"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
