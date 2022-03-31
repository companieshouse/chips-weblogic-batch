#!/bin/bash

EXPECTED_RESULT=$1

OUTPUT=`sqlplus  -s ${CHIPS_SQLPLUS_CONN_STRING} << EOF
        set head off;
        select key
        from chipstab.batch_process_parameters
        where domain = 'CHIPS'
        and sub_domain = 'DIRECTORS'
        and subject_area = 'PARAMETERS'
        and key like 'BULK_%_TMSP'
        order by param_val asc;
EOF`

RESULT=`echo ${OUTPUT} | sed 's/ $//g'`

if [[ "${RESULT}" != "${EXPECTED_RESULT}" ]]; then
        echo "DB params order ${RESULT} does not match expected order ${EXPECTED_RESULT}"
        exit 1
fi

exit 0
