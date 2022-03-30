#!/bin/bash

sqlplus -s -L ${CHIPS_SQLPLUS_CONN_STRING} <<EOF
  alter session set current_schema=chipstab;
  set head off;
  set serveroutput on;
  WHENEVER SQLERROR EXIT SQL.SQLCODE

  DECLARE
   v_day_of_week           NUMBER (1) := 0;
   v_date_increase         NUMBER (2) := 1;
  BEGIN

  select to_char(sysdate,'D') into v_day_of_week from dual;
  v_date_increase := 1;

  update batch_process_parameters
  set param_val = TO_CHAR((to_date(param_val,'DD/MM/YYYY HH24:MI:ss')+v_date_increase) - INTERVAL '45' MINUTE, 'DD/MM/YYYY HH24:MI:SS')
  where  key = 'BULK_EVENT_TMSP';

  update batch_process_parameters
  set param_val = TO_CHAR((to_date(param_val,'DD/MM/YYYY HH24:MI:ss')+v_date_increase) - INTERVAL '60' MINUTE, 'DD/MM/YYYY HH24:MI:SS')
  where  key = 'BULK_MERGE_TMSP';

  update batch_process_parameters
  set param_val = TO_CHAR((to_date(param_val,'DD/MM/YYYY HH24:MI:ss')+v_date_increase) - INTERVAL '60' MINUTE, 'DD/MM/YYYY HH24:MI:SS')
  where  key = 'BULK_PUB_TMSP';

  COMMIT;
  END;
  /
EOF

exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "Failed to reset director batch process parameters: SQLERROR with SQL.SQLCODE $exit_code"
  exit 1
fi

exit 0
