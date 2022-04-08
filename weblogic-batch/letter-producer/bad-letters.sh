#!/bin/bash

cd /apps/oracle/letter-producer

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# Set up mail config for msmtp & load alerting functions
envsubst < ../.msmtprc.template > ../.msmtprc
source ../scripts/alert_functions

# set up logging
LOGS_DIR=../logs/letter-producer
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-bad-letters-$(date +'%Y-%m-%d_%H-%M-%S').log"

exec >> ${LOG_FILE} 2>&1

echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo `date` Starting bad-letters

# TODO: below here needs to be re-worked for cloud migration:
#   - considering directory / mount availablity

cd $HOME/wlenvp1domain/batch/letterProducerOutput

find . -name '*.xml' -type f -print | grep -v large_font | grep -v schedule |  grep -v DissCerts | grep '_'>/tmp/bad_letters

cut -c30-39 /tmp/bad_letters>/tmp/bad_letter_id

cat /tmp/bad_letter_id

email_report_CHAPS_group_f ("Weekly Bad Letter Ids","`cat /tmp/bad_letter_id`")

echo `date` Ending bad-letters
echo  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~