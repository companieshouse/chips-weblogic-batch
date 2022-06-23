#!/bin/bash

# sed command to add export to beginning of each line and quote values
env | sed 's/^/export /;s/=/&"/;s/$/"/' > /apps/oracle/env.variables

# set weblogic user crontab
su -c 'crontab /apps/oracle/cron/crontab.txt' weblogic

# Start cron 
crond -n
