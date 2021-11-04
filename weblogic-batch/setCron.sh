#!/bin/bash

# sed command to add export to beginning of each line
env | sed 's/^/export /' > /apps/oracle/env.variables

# set weblogic user crontab
su -c 'crontab /apps/oracle/cron/crontab.txt' weblogic

# Start cron 
crond -n
