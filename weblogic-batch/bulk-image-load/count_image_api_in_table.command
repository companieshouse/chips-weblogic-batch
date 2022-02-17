#!/bin/bash

OUTPUT=`sqlplus  -s ${CHIPS_SQLPLUS_CONN_STRING} << EOF
       set head off;
       select count(*) from chipstab.image_api_in;
EOF`

#echo count_image_api_in_table.command OUTPUT = $OUTPUT
OUTPUT=`echo "${OUTPUT}" | head -2`
RESULT=`echo ${OUTPUT} | sed 's/ //g'`

echo Result of count_image_api_in_table is $RESULT

## if we have a 1 returned, then we could have an error - exit 1 for parent script
#(( ${RESULT} > 10 )) && exit 1

exit 0
