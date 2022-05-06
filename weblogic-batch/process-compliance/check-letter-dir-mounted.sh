#!/bin/bash

## Test to check that auto mounted directories are usable
## script returns 1 if directory has not been mounted, and 0 if mounted
## normally the directory looks like:
## drwxr-xr-x  4 wlenvp1  bea 4096 May 23  2008 wlenvp1letteroutput
## if failed the permissions look like
## dr-xr-xr-x 1 root root 1 Jan 14 10:06 wlenvp1letteroutput

BATCH_FOLDER="/apps/oracle/input-output"

ls ${BATCH_FOLDER}/letterProducerOutput  > /dev/null 2>&1
if [[ $? != 0 ]];then
  exit 1
fi

exit 0
