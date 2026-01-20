#!/bin/bash
# =============================================================================
#
#  Module Name  : image-regeneration.sh
#  Author       : Glen Neal
#  $Date: 2022-03-28 $
#  Description  :
#
#  Core script to invoke image regeneration within CHIPS as part of Cloud based batch
#  processing.
#
# Supports regeneration of image types:
# - FES
# - Standard (non FES)
#
#  Handles logging in Cloud based batch standard manner.
#
#  #USAGE_MSG="Usage: ./image-regeneration.sh [imageRegenerationType(fes_image_regen|standard_image_regen)] [transactionIdsFile]"
#
# =============================================================================


# load variables created from setCron script
source /apps/oracle/env.variables
source /apps/oracle/scripts/logging_functions

LIBS_DIR=/apps/oracle/libs
CLASSPATH=${CLASSPATH}:.:${LIBS_DIR}/log4j-api.jar:${LIBS_DIR}/log4j-core.jar:${LIBS_DIR}/wlthint3client.jar:${LIBS_DIR}/commons-lang.jar:/apps/oracle/image-regeneration/image-regeneration.jar

# set up logging
LOGS_DIR=../logs/image-regeneration
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-image-regeneration-$(date +'%Y-%m-%d_%H-%M-%S').log"

# Enable std Cloud batch logging via stdout whilst also supporting ability for invoking scripts to capture it too
# so that calling script can redirect stdout too thus be able to log independently.
# exec > changes stdout to refer to what comes next
# being process substitution of >(tee "${LOG_FILE}") to feed std program input 
# 2>&1 to redirect stderr to same place as stdout
# Net impact is to changes current process std output so output from following commands goto the tee process
exec > >(tee "${LOG_FILE}") 2>&1

cd /apps/oracle/image-regeneration || { f_logError "Failure to cd to image-regeneration directory"; exit 1; } 


f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting image-regeneration"

USAGE_MSG="Usage: ./image-regeneration.sh [imageRegenerationType(fes_image_regen|standard_image_regen)] [transactionIdsFile]"

# Validate args length
if [ "$#" -ne 2 ]
then
  f_logError "Invalid number of arguments"
  f_logError "$USAGE_MSG"
  exit 2
fi

#Assign the arguments
imageRegenerationType=$1; shift
transactionIdsFile=$1; shift

# Validate imageRegenerationType
if [ "$imageRegenerationType" = "standard_image_regen" ]
then
  IMAGE_REGENERATE_CLIENT_NAME="uk.gov.companieshouse.imaging.ImagingRegenerateClient"
  f_logInfo "Selected image regeneraton of STANDARD image/s"
elif [ "$imageRegenerationType" = "fes_image_regen" ]
then
  IMAGE_REGENERATE_CLIENT_NAME="uk.gov.companieshouse.imaging.FESImagingRegenerateClient"
  f_logInfo "Selected image regeneraton of FES image/s"
else
  f_logError "Invalid value for imageRegenerationType was supplied. Value supplied was: %s" "${imageRegenerationType}"
  f_logError "$USAGE_MSG" 
  exit 2
fi

# Validate transactionIdsFile exists
if [ -f "$transactionIdsFile" ]; then
  f_logInfo "Using transactionIdsFile: %s" "${transactionIdsFile}"
else
  f_logError "The transactionIdsFile supplied does not exist. Check existence/permissions of the file: %s" "${transactionIdsFile}"
  exit 2
fi

# Validate the existing transactionIdsFile is not empty
if ! [ -s "$transactionIdsFile" ]; then
  f_logError "The transactionIdsFile supplied is empty. Must have content in the file: %s" "${transactionIdsFile}"
  exit 2
fi

/usr/java/jdk/bin/java -Din=image-regeneration -cp "${CLASSPATH}" -Dlog4j.configurationFile=log4j2.xml ${IMAGE_REGENERATE_CLIENT_NAME} "${JMS_JNDIPROVIDERURL}" "$transactionIdsFile" "${WEBLOGIC_ADMIN_USERNAME}" "${ADMIN_PASSWORD}"

exit_code=$?
if [ $exit_code -gt 0 ]
then
  f_logError "Non-zero exit code for image-regeneration java execution. The exit code was %s." "${exit_code}"  
  exit 1
fi

f_logInfo "Ending image-regeneration"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
