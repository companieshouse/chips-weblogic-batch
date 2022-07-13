#!/bin/bash
source /apps/oracle/scripts/logging_functions

OUTPUT=`sqlplus  -s ${CHIPS_SQLPLUS_CONN_STRING} << EOF
       set head off;
       select count(*) from chipstab.image_api_in;
EOF`

OUTPUT=`echo "${OUTPUT}" | head -2`
RESULT=`echo ${OUTPUT} | sed 's/ //g'`

f_logInfo "Result of count_image_api_in_table is $RESULT"

exit 0
