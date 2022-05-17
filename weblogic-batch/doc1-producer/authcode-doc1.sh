#!/bin/bash

cd /apps/oracle/doc1-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst </apps/oracle/.msmtprc.template >/apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

# Logging already set up in calling script
source /apps/oracle/scripts/logging_functions

f_logInfo "Starting Auth Code process."

AUTHCODE_SOURCE="/apps/oracle/input-output/authcodeInput"
AUTHCODEIN_LOCATION="/apps/oracle/input-output/afpInput"
AUTHCODEOUT_LOCATION="/apps/oracle/input-output/afpOutput"
DOC1_GATEWAY_LOCATION_EW="/apps/oracle/input-output/gateway/doc1/ew"

###########################################
#Check there are any files to process
###########################################

#Make sure there isn't a file left in afpOutput which will end up being sent to APS as a duplicate
f_logInfo "Removing spurious authcode files"
rm -f $AUTHCODEOUT_LOCATION/AUT*

FILECOUNT=$(ls -1 $AUTHCODE_SOURCE/AUT* 2>/dev/null | wc -l)

if [ 0 -eq ${FILECOUNT} ]; then
    email_CHAPS_group_f "No Doc1 files found to process for Auth Code" "There are no files in $AUTHCODE_SOURCE. Please investigate."
    f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    exit 1
fi

f_logInfo "Auth code file is in $AUTHCODE_SOURCE"

######################################################
## Copy todays Auth Code file to the Doc1 Input Folder
######################################################
f_logInfo "Copying todays file to Doc1 Input Folder"
cp $AUTHCODE_SOURCE/AUT* $AUTHCODEIN_LOCATION

sleep 15
################################################################
## Check file has been processed and moved to Doc1 Output Folder
################################################################
f_logInfo "Checking file has moved to Output folder, then move it to Gateway"

COUNT=0
f_logInfo "Starting Count - COUNT set to $COUNT"
f_logInfo "AUTHCODEOUT_LOCATION is $AUTHCODEOUT_LOCATION"

while [ $COUNT -lt 10 ]; do
    f_logInfo "Calling ls"
    ls -lart $AUTHCODEOUT_LOCATION/AUT* | while IFS= read -r line; do f_logInfo "$line"; done

    FILECOUNT_2=$(ls -1 $AUTHCODEOUT_LOCATION/AUT* 2>/dev/null | wc -l)
    f_logInfo "FILECOUNT_2 is $FILECOUNT_2"

    if [ $FILECOUNT_2 -gt 0 ]; then

        cp $AUTHCODEOUT_LOCATION/AUT* $DOC1_GATEWAY_LOCATION_EW
        f_logInfo "Auth Code file moved from Output folder to Gateway."
        COUNT=11
        f_logInfo "File Found. Count set to $COUNT "
        rm $AUTHCODEOUT_LOCATION/AUT*
        f_logInfo "Authcode file removed from Output folder."
    else
        ((COUNT = COUNT + 1))
        f_logInfo "Check count = $COUNT "
        sleep 20
    fi
done

if [ $COUNT -eq 10 ]; then
    f_logError "No Auth Code Output file has been produced. Please Investigate."
    email_CHAPS_group_f "Auth Code process failure." "Auth Code process failed. No output file created. Please Investigate."
    f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    exit 1
fi

f_logInfo "Moving AUTHCODE.txt file to $HOME/doc1-producer/authcode_backup"
mv $AUTHCODE_SOURCE/AUTHCODE*.txt $HOME/doc1-producer/authcode_backup

f_logInfo "Finished Auth Code Process."
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
