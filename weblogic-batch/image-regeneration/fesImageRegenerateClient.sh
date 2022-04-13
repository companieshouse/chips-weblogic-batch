#!/bin/bash
# =============================================================================
#
#  Module Name  : fesImageRegenerateClient.sh
#  Author       : Glen Neal
#  $Date: 2022-03-28 $
#  Description  :
#
#  Wrapper script used to initiate image regeneration of FES images.
#  
#  A list of transaction ids required to be regenerated should be supplied
#  in a file with one transaction listed per line (without field 
#  separators, like commas).
#  
#  The file should be given a unique <filename> (e.g. INC12345678) and
#  assigned to the transactionIdsFile variable.
# 
#  Then the script can be invoked.
#
#  A log file, called <filename>.log will be created.
#
# =============================================================================

transactionIdsFile=transaction_ids
scriptLogFile=${transactionIdsFile}.log

source /apps/oracle/scripts/logging_functions

./image-regeneration.sh fes_image_regen ${transactionIdsFile} >  ${scriptLogFile} 2>&1
status=$?

if [ $status -gt 0 ]
then
    f_logError "Non-zero exit code of %s for fesImageRegenerateClient.sh execution. Check the script log file for error details: %s" ${status} ${scriptLogFile}
    exit 1
else 
    f_logInfo "Successfully completed fesImageRegenerateClient.sh execution. Check the script log file for results: %s" ${scriptLogFile}
fi

