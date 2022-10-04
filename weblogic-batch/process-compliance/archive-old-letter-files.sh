#!/bin/bash

cd /apps/oracle/process-compliance

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up standard logging
LOGS_DIR=../logs/process-compliance
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-archive-old-letter-files-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> "${LOG_FILE}" 2>&1

LP_FOLDERPATH=/apps/oracle/input-output/letterProducerOutput/20*
LP_ARCHIVEPATH=/apps/oracle/input-output/letterProducerOutput/archive
LP_AGEINDAYSTOARCHIVE=7

D1_FOLDERPATH=/apps/oracle/input-output/doc1ProducerOutput/20*
D1_ARCHIVEPATH=/apps/oracle/input-output/doc1ProducerOutput/archive
D1_AGEINDAYSTOARCHIVE=7

## archive function
f_archive() {
  folder=${1}
  ARCHIVEPATH=${2}
  f_logInfo "Archiving ${folder} to ${ARCHIVEPATH}"

  tar -cf ${folder}.tar ${folder}
  if [ "$?" -ne 0 ]; then
    f_logError "ERROR in tar command of ${folder}. Please investigate."
    exit
  else
    gzip ${folder}.tar
    target_filename="${ARCHIVEPATH}/$(basename ${folder}).tar.gz"
    if [ ! -e ${target_filename} ]; then
      mv ${folder}.tar.gz ${ARCHIVEPATH}
    fi
    # only delete source folder if archived copy exists
    if [ ! -e ${target_filename} ]; then
      f_logError "${target_filename} not created. Please investigate."
      exit
    else
      f_logInfo "${target_filename} exists, deleting ${folder}"
      rm -r ${folder}
    fi
  fi
}

## create archive directories if not there
if [ ! -d ${LP_ARCHIVEPATH} ]; then
  mkdir -p ${LP_ARCHIVEPATH}
fi

if [ ! -d ${D1_ARCHIVEPATH} ]; then
  mkdir -p ${D1_ARCHIVEPATH}
fi

## tar and gzip folders that are older than x days
for lp_folder in `find ${LP_FOLDERPATH} -prune -type d -mtime +${LP_AGEINDAYSTOARCHIVE}`
do
  f_archive ${lp_folder} ${LP_ARCHIVEPATH}
done

for d1_folder in `find ${D1_FOLDERPATH} -prune -type d -mtime +${D1_AGEINDAYSTOARCHIVE}`
do
  f_archive ${d1_folder} ${D1_ARCHIVEPATH}
done

f_logInfo "end archive-old-letter-files.sh script ..."
