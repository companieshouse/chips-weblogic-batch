#!/bin/bash

OUTPUT=`sqlplus  -s ${CHIPS_SQLPLUS_CONN_STRING} << EOF
       set head off;
       select distinct(1) from chipstab.officer_event_match ;
EOF`

OUTPUT=`echo "${OUTPUT}" | head -2`
RESULT=`echo ${OUTPUT} | sed 's/ //g'`

## if we have a 1 returned, then we could have an error - exit 1 for parent script
[ ${RESULT} = "1" ] && exit 1

exit 0
