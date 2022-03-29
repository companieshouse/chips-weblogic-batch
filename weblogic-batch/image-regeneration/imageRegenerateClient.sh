#!/bin/bash
# =============================================================================
#
#  Module Name  : imageRegenerateClient.sh
#  Author       : Glen Neal
#  $Date: 2022-03-28 $
#  Description  :
#
#  Wrapper script used to initiate image regeneration of standard (non FES) images.
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

./image-regeneration.sh standard_image_regen ${transactionIdsFile} >  ${scriptLogFile} 2>&1
status=$?

if [ $status -gt 0 ]; then
    echo "Non-zero exit code for imageRegenerateClient.sh execution. Check the script log file for error details: ${scriptLogFile}"
    exit 1
else 
    echo "Successfully completed imageRegenerateClient.sh execution. Check the script log file for results: ${scriptLogFile}"
fi
