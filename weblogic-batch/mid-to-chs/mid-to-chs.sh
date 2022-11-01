#!/usr/bin/bash

###############################################################################
# Script to write Missing Image Delivery (MID) images to an s3 bucket for CHS #
# Author ijenkins                                                             #
# December 2020                                                               #
# Migrated to AWS Oct 2022                                                    #
# Parameters required: None                                                   #
###############################################################################

# This script reads MID (formerly SCUD) images from a network file share and
# eventually writes them to an s3 bucket where they can be picked up by CHS.
#
# The script will be run every 10 minutes from the Weblogic server cron.
#
# A network share is defined as $data_dir in the properties file.  It will contain
# zero, one or multiple pairs of files, where each pair consists of a header file
# and an associated tiff image.
#
# The script will read the header files and extract the customer-ref field, which
# will consist of a 15 character payment reference followed by a further 10
# bytes of data.  These 10 bytes will contain either a transaction_id or two hyphens
# followed by a barcode.
#
# The script then runs a query against the OLTP database.  It has to use
# runRemoteCommand_OLTPDB.ksh to achieve this, since there is no Oracle client on
# the Weblogic servers.  It needs to use the OLTP database because it requires
# access to the api_document_categories table.
#
# The SQL script uses either the transaction_id or the barcode in the header file
# to extract the data needed to construct a metadata object (see 
# uk.gov.ch.imagesender.domain.Metadata.java in the Chips github repository).
#
# The script will now (assuming no failures) have a transaction_id, regardless of
# whether there was a transaction_id or a barcode in the original header file. So the
# next step is to write the tiff image file to the $cloud_images_dir using the
# transaction_id as the file name
# 
# The extracted metadata is then passed to image-api-message-generator.jar.
# This is a new standalone jar file which exists in its own repository.  It sends a
# JMS message to the ImageApiMessageProducer queue with the metadata as the payload.
#
# The JMS message will be processed by the ImageApiMDB, which will look for the
# image on the network share using temporaryImageStorageService.getImageContent(). 
# Once ImageApiMDB has obtained the image, it will add it to the payload alongside the
# metadata. The payload, which now contains the tiff image, is sent to the 
# appropriate s3 bucket via the sendPayload method of ImageApiMDB, which in turn invokes
# the send method in class ImageToS3StoreSender.java

# As far as this script is concerned, the process is now complate.  The payload in the 
# s3 bucket is picked up by the front end and inserted into the 'queue' collection.  From
# there, the image is automatically added to the relevant CHS transaction (it should
# be visible on CHS more-or-less straight away).

########## Function definitions ##########

send_error_mail()
{
#  param1: email body
#  param2: email subject
email_report_f "${EMAIL_ADDRESS_CSI}" "${ENVIRONMENT_LABEL} $2" "Hi there from WebLogic Batch mid_to_chs.sh job. $1. Have a great day. "
}

move_to_error_dir()
{
if mv $header_file $error_dir; then
    f_logInfo $header_file moved to $error_dir
else
    send_error_mail "Error moving $header_file to $error_dir" "mid-to-chs: Error moving header file to error dir"
fi
if mv $tiff_file $error_dir; then
    f_logInfo $tiff_file moved to $error_dir
else
    send_error_mail "Error moving $tiff_file to $error_dir" "mid-to-chs: Error moving tiff_file to error dir"
fi
}

########## End of function definitions ##########

cd /apps/oracle/mid-to-chs/

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < image-api-message-generator.template > image-api-message-generator.properties
source image-api-message-generator.properties

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

export CLASSPATH=$CLASSPATH:.:/apps/oracle/libs/wlfullclient.jar:/apps/oracle/libs/log4j.jar:/apps/oracle/libs/javax.ws.rs-api.jar:/apps/oracle/libs/image-sender.jar:/apps/oracle/mid-to-chs/image-api-message-generator.jar

# set up logging
LOGS_DIR=../logs/mid-to-chs
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-mid-to-chs-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

# done and error folders, check if persistance needed 
mkdir -p ${done_dir}
mkdir -p ${error_dir}

# Enable std Cloud batch logging via stdout whilst also supporting ability for invoking scripts to capture it too
# so that calling script can redirect stdout too thus be able to log independently.
# exec > changes stdout to refer to what comes next
# being process substitution of >(tee "${LOG_FILE}") to feed std program input 
# 2>&1 to redirect stderr to same place as stdout
# Net impact is to changes current process std output so output from following commands goto the tee process
exec > >(tee "${LOG_FILE}") 2>&1

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting mid-to-chs"

f_logInfo `date`: mid-to-chs.sh starts

if [ $(ls $data_dir/*txt 2>/dev/null | wc -w) -eq 0 ]; then
    f_logInfo No files to process
    f_logInfo `date`: mid-to-chs.sh ends
    exit 0
fi

mid_to_chs_command_using_barcode="mid-to-chs-using-barcode.command"
mid_to_chs_command_using_transaction="mid-to-chs-using-transaction.command"
for header_file in $data_dir/*txt
do
    dos2unix $header_file $header_file 2>/dev/null
 
    tiff_file=${header_file%.*}.tif
    if ! test -f "$tiff_file"; then
        f_logInfo No corresponding tiff file for $header_file
        send_error_mail "No corresponding tiff_file found for $header_file" "mid-to-chs: No tiff file found"
        continue
    fi

    export reference_type=""
    export transaction_id=""
    export barcode=""
    export invalid_header_file=false
    export mid_to_chs_command=""
    export metadata=""

    cust_ref=`grep 'Customer Ref:' $header_file`

#   Establish whether we have a barcode or a transaction_id in the header file
    trans_or_barcode_indicator=${cust_ref:39:2}
    if [[ $trans_or_barcode_indicator == "--" ]]; then
        reference_type="barcode"
        barcode=${cust_ref:41:8}
        f_logInfo barcode is $barcode
        mid_to_chs_command="./${mid_to_chs_command_using_barcode}"
    else
        reference_type="transaction"
        transaction_id=${cust_ref:39:10}
        f_logInfo transaction_id is $transaction_id
        mid_to_chs_command="./${mid_to_chs_command_using_transaction}"
        if ! [ "$transaction_id" -ge 0 ] 2>/dev/null ; then
           f_logInfo "Invalid transaction_id not numeric"
           invalid_header_file=true
        fi
    fi
    
    f_logInfo ----------------------------------------
    f_logInfo Header file is $header_file
    f_logInfo Tiff file is $tiff_file
    f_logInfo Reference is \"${cust_ref##*( )}\"
    f_logInfo ----------------------------------------
    f_logInfo ""

    if [ "$invalid_header_file" = true ]; then
        f_logInfo header file contains invalid customer ref
        send_error_mail "Error parsing header file. The header and associated tiff file will be moved to: $error_dirn" "mid-to-chs: Error parsing mid header file"
        move_to_error_dir 
        continue
    fi        
    
    if [ "$reference_type" = barcode ]; then
        f_logInfo barcode = ${barcode} now run sqlplus command
        metadata=$($mid_to_chs_command $barcode)
    elif 
       [ "$reference_type" = transaction ]; then
        f_logInfo there are this many characters in the trans file
        f_logInfo $(echo ${transaction_id}| wc -c)
        f_logInfo transaction_id = ${transaction_id} now run sqlplus command
        metadata=$($mid_to_chs_command $transaction_id)
    fi

    f_logInfo Retrieved metadata from SQL is $metadata
    metadata=`echo $metadata | awk -F" "  '{print $NF}'`
    f_logInfo metadata now is $metadata
    good_metadata_pattern='????????|*'
    if [[ "$metadata" != $good_metadata_pattern ]]; then
        f_logInfo Bad metadata
        send_error_mail "mid to chs SQL Command did not return valid metadata" "mid-to-chs: Metadata error"
        move_to_error_dir 
        continue
    fi
#   If we started off with a barcode we can now get the transaction_id out of the metadata
    if [ "$reference_type" = barcode ]; then
       transaction_id=`echo $metadata | awk '{split($0,a,"|");print a[5]}'`
       f_logInfo length of transaction_id is
       f_logInfo $transaction_id| awk '{print length}'
    fi 
    
#   we must have the transaction_id by now so we can write the file to $cloud_images_dir with the correct name
    f_logInfo moving $tiff_file to $cloud_images_dir/$transaction_id
    transaction_id="${transaction_id%"${transaction_id##*[![:space:]]}"}" 
    if mv $tiff_file $cloud_images_dir/${transaction_id}; then
       f_logInfo move successful
    else
       f_logInfo failed to move $tiff_file to $cloud_images_dir/$transaction_id
       send_error_mail "Failed to move $tiff_file to $cloud_images_dir/$transaction_id" "mid-to-chs: Failure to move tiff file"
       continue
    fi
    f_logInfo changing permissions
    chmod 664 $cloud_images_dir/${transaction_id}
    f_logInfo permissions changed 
#   write-to-image-api.sh sends the message to the ImageApiMessageProducer JMS
#   queue using $metadata as the payload
    f_logInfo "Writing to api..." 
    ./write-to-image-api.sh $metadata
    result_code=$?
    if [ $result_code -ne 0 ]; then
        f_logInfo write-to-image-api.sh returned result code $result_code
        f_logInfo header file $header_file will be moved to $error_dir
        send_error_mail "write-to-image-api.sh failed with result_code $result_code" "mid-to-chs: write-to-image-api.sh failed"
        mv $header_file $error_dir
    else
        f_logInfo "write complete" 
#       if we get this far everything has worked.  The tiff has gone to $cloud_images_dir.  The header
#       file is still in $data_dir; we will move it to $done_dir to keep a record of successful uploads
        if mv $header_file $done_dir; then
            f_logInfo $header_file successfully moved to $done_dir
        else
            f_logInfo Failed to move processed file $header_file to $done_dir 
            send_error_mail "Failed to write $header_file to $done_dir" "mid-to-chs: Write to $done_dir failed"
        fi
    fi

done

f_logInfo "Ending mid-to-chs"
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
