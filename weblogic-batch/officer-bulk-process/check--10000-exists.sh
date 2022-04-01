#!/bin/bash

#       PURPOSE: A cronned script to warn CSI that the Publish stage left a -10000 row pair in chipstab.officer_detail_match
#                If that happens, just delete it !

cd /apps/oracle/officer-bulk-process

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

## Check to make sure we did not leave after PUBLISH stage any -10000 WORK_ITEM_REFERENCE
./check-officer-publish-finished.command

if [ $? -gt 0 ]; then
    echo "Non-zero exit code for check-officer-publish-finished.command"
    email_CHAPS_group_f " $(basename $0): Fix Zombie Officer in chipstab.officer_detail_match- Bulk Officer Job."
    exit 1
fi
