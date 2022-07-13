#!/bin/bash
source /apps/oracle/scripts/logging_functions

OUTPUT=`sqlplus  -s ${CHIPS_SQLPLUS_CONN_STRING} << EOF
       set head off;
       select count(*) from chipstab.officer_detail_match o where o.WORK_ITEM_REFERENCE = -10000;
EOF`

OUTPUT=`echo "${OUTPUT}" | head -2`
RESULT=`echo ${OUTPUT} | sed 's/ //g'`

f_logInfo "Rows in OFFICER_DETAIL_MATCH with WORK_ITEM_REFERENCE = -10000: ${RESULT}"

(( $RESULT > 10 )) && exit 1

exit 0
