#!/bin/bash

barcode=$(cat /apps/oracle/mid-to-chs/barcode)

OUTPUT=`sqlplus -s ${CHIPS_SQLPLUS_CONN_STRING} << EOF
set head off;
set feedback off;
alter session set current_schema=chipstab;
select coalesce(form_barcode,'11111111') || '|' ||
       incorporation_number || '|' ||
       case when form_type is not null
       then form_type
       else
       ttype.transaction_type_short_name
       end
       || '|' ||
       case when document_category is not null
       then document_category
       else
       'miscellaneous'
       end
       || '|' ||
       transaction_id || '|' ||
       case when parent_transaction_id is not null
       then parent_transaction_id || '|'
       ||
       (select transaction_type_short_name from transaction_type where transaction_type_id =
       (select transaction_type_id from transaction where transaction_id = parent_transaction_id)) || '|'
       else null
       end
       ||
       to_char(transaction_status_date, 'YYYY-MM-DD')
from transaction trans
inner join
transaction_type ttype
on trans.transaction_type_id = ttype.transaction_type_id
inner join corporate_body cb
on trans.corporate_body_id = cb.corporate_body_id
left outer join
api_document_categories apicat
on ttype.transaction_type_short_name = apicat.form_type
left outer join transaction_relationship trel
on trans.transaction_id = trel.child_transaction_id
where form_barcode='$barcode';
EOF`

OUTPUT=`echo "${OUTPUT}" | head -2`
echo $OUTPUT
