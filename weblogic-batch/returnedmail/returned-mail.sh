#!/bin/bash

# This script retrieves a zip file from APS and creates a returned_mail.csv file.
#
# The returned_mail.csv file is copied to the batenvp1/input/returned_mail directory on chw-envp1 ready for processing
# by the /export/home/batenvp1/bin/returned_mail/04_returned_mail_bulkload.ksh script (which is cronned to run on chw-envp1).
#
# The file on the APS sftp server will be in the format CompaniesHouseReturnMailYYYYMMDD.zip.  We will not
# know the exact filename in advance.  Also, we cannot assume that there is only one file with this pattern.
# We will therefore retrieve CompaniesHouseReturnMail*.zip and determine which is the latest file using shell
# commands.
#
# As a further check, we ensure that the file identified as the latest is not identical to the previous
# file processed.
#
# Once we have verified that we have a valid  file to process, we will unzip it, producing one or more
# csv files.  We will concatenate *.csv to produce one returned_mail.csv file. We then need to dos2unix this
# file and copy it to batenvp1/input/returned_mail.
#

cd $HOME/bin/returnedmail
. ./process.properties

this_progname="$(basename $BASH_SOURCE)"
log="${log_location}create_returned_mail_input_file.log"
local_receive_dir="$HOME/received/returnedmail/"
local_archive_dir="$HOME/archive/returnedmail/"

#output_dir="$HOME/returnedmailtestoutputdir"
#output_dir="/home/batenvp1/input/returned_mail/"
output_dir="/mnt/nfs/oltp/input/returned_mail"

latest_zipfile=""
file_pattern="CompaniesHouse*.zip"
previous_zipfile=$previous_files_dir'previous_returnedmail_zipfile'

# $returned_mail_file is the input file used by the cron job that does the database upload
returned_mail_file=$local_receive_dir"returned_mail.csv"
temp_file=$local_receive_dir"temp_file"

exec &>> $log
echo "`date`: $this_progname begins"
echo "Retrieving files via sftp"

# get the file from APS
#if sftp -b <(echo -e "cd $remote_path\n lcd $local_receive_dir\n ls") $remote_account@$remote_server
if sftp -b <(echo -e "cd $remote_path\n lcd $local_receive_dir\n get $file_pattern") $remote_account@$remote_server
then
    echo "sftp ended OK"
else
    echo "Failure in sftp"
    echo -e "$this_progname running on $server has failed to retrieve zip file from APS via sftp " | \
    mail -s "CHAPS Alert: Returned Mail sftp failure" \
    -r $email_from_address $email_recipient_list
    exit 1
fi
latest_zipfile=`ls -tr ${local_receive_dir}${file_pattern} 2>/dev/null | tail -1`

echo latest_zipfile is $latest_zipfile

if [ ! -f  $latest_zipfile ]
then
    echo "No zip file to process, exiting"
    exit 1
else
    echo "latest_zipfile = $latest_zipfile"
fi

base_name="${latest_zipfile##*/}"
echo "base_name is $base_name"

# Make sure the file isn't the same as the previous one processed

if  cmp -s $latest_zipfile $previous_zipfile
then
    echo duplicate_file_found $latest_zipfile
    echo "$latest_zipfile file has identical contents to previous file, so file not processed"
    echo -e "$this_progname running on $server has determined that the latest file is: $latest_zipfile, " \
    " but this file has previously been processed" | \
    mail -s "CHAPS Alert: Identical returned mail file detected" \
    -r $email_from_address $email_recipient_list
    exit 1
else
    echo "File contents different from previous run, so OK to continue."
fi

# unzip the file.
unzip $local_receive_dir$base_name -d $local_receive_dir

if [ $? -ne 0 ]
then
    echo "Failed to unzip $latest_zipfile, exiting"
    echo -e "$this_progname running on $server has failed to unzip $latest_zipfile, " | \
    mail -s "CHAPS Alert: Failure to unzip returned_mail file" \
    -r $email_from_address $email_recipient_list
    exit 1
else
    echo "Successfully unzipped $latest_zipfile"
fi

# We should now have one or more csv files in the returnedmail directory.  We need to make sure that we have just one input file to process.
# The csv files do not have headers or trailers, so we can just concatenate them.

# Update 20-07-2021
# When the csv files are unzipped, they no longer have terminating newlines.
# So the following line adds a newline after every file...
# 11-04-2022 The APS files don't seem to end in csv any more, so we will now look for
# 2*.txt instead of 2*.txt.csv
for i in $local_receive_dir/2*.txt; do cat "${i}"; echo; done  > $temp_file
# ...but we don't want the output file to have a trailing newline so the next line strips it off
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' $temp_file
awk -F, '{if(length($0) < 15 && length($1) > 6 && (length($2) == 3 || length($2) == 4)) print }' $temp_file > $returned_mail_file

rm $local_receive_dir/2*txt
timestamp=`date +"%d-%m-%Y_%H%M%S"`
mv $local_receive_dir/Exceptions $local_archive_dir/Exceptions$timestamp
dos2unix $returned_mail_file
if [ $? -ne 0 ]
then
    echo "Failed to dos2unix $returned_mail_file, exiting"
    exit 1
else
    echo "Successfully ran dos2unix on $returned_mail_file"
fi

cp $latest_zipfile $local_archive_dir$base_name
if [ $? -ne 0 ]
then
    echo "Failed to copy $latest_zipfile to archive directory, exiting"
    echo -e "$this_progname running on $server has failed to copy $latest_zipfile to archive" | \
    mail -s "CHAPS Alert: Failure to copy Returned Mail file to archive" \
    -r $email_from_address $email_recipient_list
    exit 1
else
    echo "Successfully copied $latest_zipfile to $local_archive_dir"
fi

mv $latest_zipfile $previous_zipfile
if [ $? -ne 0 ]
then
    echo "Failed to move $latest_zipfile to $previous_zipfile,  exiting"
    echo -e "$this_progname running on $server has failed to copy $latest_zipfile to $previous_zipfile" | \
    mail -s "CHAPS Alert: Failure moving zip file to $previous_zipfile" \
    -r $email_from_address $email_recipient_list
    exit 1
else
    echo "Successfully moved $latest_zipfile to $previous_zipfile"
fi

mv $returned_mail_file $output_dir
if [ $? -ne 0 ]
then
    echo "Failed to move $returned_mail_file to $output_dir, exiting"
    echo -e "$this_progname running on $server has failed to move $returned_mail_file to $output_dir" | \
    mail -s "CHAPS Alert: Failure moving Returned Mail file to $output_dir" \
    -r $email_from_address $email_recipient_list
    exit 1
else
    echo "Successfully moved $returned_mail_file to $output_dir"
echo "`date`: returned_mail.sh ended OK"
echo
echo "*************************************************************"
echo

echo -e "$this_progname running on $server has successfully processed $latest_zipfile" | \
    mail -s "CHAPS Alert: $this_progname ended OK" \
    -r $email_from_address $email_recipient_list
