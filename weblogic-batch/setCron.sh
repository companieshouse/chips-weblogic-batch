#!/bin/bash

# sed command to add export to beginning of each line and quote values
env | sed 's/^/export /;s/=/&"/;s/$/"/' > /apps/oracle/env.variables

# append derived variable CHIPS_SQLPLUS_CONN_STRING to properties file
CHIPS_SQLPLUS_CREDS=${DB_USER_CHIPSDS}/${DB_PASSWORD_CHIPSDS}
CHIPS_SQLPLUS_PATH=$(echo ${DB_URL_CHIPSDS} | awk -F'@' '{print $2}' |  awk -F':' '{print $1 ":" $2 "/" $3}')
echo "export CHIPS_SQLPLUS_CONN_STRING=\"${CHIPS_SQLPLUS_CREDS}@${CHIPS_SQLPLUS_PATH}\"" >> /apps/oracle/env.variables

# set weblogic user crontab
su -c 'crontab /apps/oracle/cron/crontab.txt' weblogic

# Start cron 
crond -n
