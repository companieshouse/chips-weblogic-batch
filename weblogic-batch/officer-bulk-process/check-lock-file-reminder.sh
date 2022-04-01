#!/bin/bash

#       PURPOSE: A cronned script to warn CSI that we forgot to take Lock File off

cd /apps/oracle/officer-bulk-process

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst <../.msmtprc.template >../.msmtprc
source ../scripts/alert_functions

if [ -f /apps/oracle/officer-bulk-process/OFFICER_LOCK_FILE_ALERT ]; then
    email_CHAPS_group_f " $(pwd)/$(basename $0): HEADS UP - OFFICER_LOCK_FILE_ALERT exists. Remove if needed !!!"
    exit 1
fi
