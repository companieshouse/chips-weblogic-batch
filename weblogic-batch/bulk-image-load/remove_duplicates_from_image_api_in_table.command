#!/bin/bash

OUTPUT=`sqlplus  -s ${CHIPS_SQLPLUS_CONN_STRING} << EOF
--Temporary table with indexes
create table tmp_dedup_image_api_in as
select * from image_api_in;

create index tmp_dedup_image_api_in_tran ON tmp_dedup_image_api_in (transaction_id);
create index tmp_dedup_image_api_in_image ON tmp_dedup_image_api_in (image_file_reference);

DECLARE
v_duplicate_count    NUMBER(10);

BEGIN

FOR image_api_in_request IN (select unique iai.image_file_reference from tmp_dedup_image_api_in iai where (select count(*) from tmp_dedup_image_api_in iaii where iaii.image_file_reference=iai.image_file_reference
and iaii.transaction_id=iai.transaction_id) > 1
)
LOOP

    select count(*) into v_duplicate_count from tmp_dedup_image_api_in iai where iai.image_file_reference=image_api_in_request.image_file_reference;

    dbms_output.put_line(TO_CHAR(SYSDATE,'hh24:mi:ss > ')||v_duplicate_count||' requests found for image_reference '|| image_api_in_request.image_file_reference);

    delete from image_api_in where image_file_reference=image_api_in_request.image_file_reference and
    rowid > any(select iai.rowid from image_api_in iai where iai.image_file_reference=image_api_in_request.image_file_reference);

    dbms_output.put_line(TO_CHAR(SYSDATE,'hh24:mi:ss > ')||SQL%ROWCOUNT||' request(s) deleted for image_reference '|| image_api_in_request.image_file_reference);

END LOOP;

END;

EOF`

echo ${OUTPUT}

OUTPUT=`sqlplus  -s ${CHIPS_SQLPLUS_CONN_STRING} << EOF
drop table tmp_dedup_image_api_in;

EOF`

echo ${OUTPUT}

exit 0
