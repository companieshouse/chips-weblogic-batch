

This is the location for various JMS administration scripts that are typically run manually by CSI or are scheduled to run on the cron.

### list-all-jms.sh
This is run when there is a need to list JMS messages held within one queue across a range of WebLogic servers.

The following parameter is required:

- The name of the queue to list messages in, e.g. uk.gov.ch.chips.jms.EfilingRequestErrorQueue

For example:
./list-all-jms.sh uk.gov.ch.chips.jms.EfilingRequestErrorQueue

The script list messages on every one of the servers that are listed in environment variables that start with the prefix `JMS_SERVER_URL_`

For example, if the following environment variables were defined, the script would list messages on both these servers:

    JMS_SERVER_URL_1=t3s://chips-ef-batch0.heritage.aws.internal:21031|JMSServer1
    JMS_SERVER_URL_2=t3s://chips-ef-batch1.heritage.aws.internal:21031|JMSServer1


### report-stuck-ef-submissions.sh

This is run in order to email a report of "stuck" JMS messages in the EfilingRequestErrorQueue across all WebLogic servers.

No parameters are required.

For example:
./report-stuck-ef-submissions.sh

The script makes use of list-all-jms.sh and processes the output from that to generate a report that is then emailed to the address 
held in the environment variable `EMAIL_ADDRESS_CSI`.


### report-stuck-chips-generic-messages.sh

This is run in order to email a report of "stuck" JMS messages in the ChipsGenericErrorQueue across all WebLogic servers.

No parameters are required.

For example:
./report-stuck-chips-generic-messages.sh

The script makes use of list-all-jms.sh and processes the output from that to generate a report that is then emailed to the address 
held in the environment variable `EMAIL_ADDRESS_CSI`.


### list-all-jms-ef-responses.sh

This is run in order to list all "stuck" EF response JMS messages in the EfilingErrorQueue across all WebLogic servers.

No parameters are required.

For example:
./list-all-jms-ef-responses.sh

The script makes use of list-all-jms.sh and processes the output from that to list all EF response messages, along with an
indication of whether they are safe to delete or need further investigation.

It will display messages on each JMS server and show:

- the object id (which is useful in the Weblogic console)
- if the response is ACCEPTED or REJECTED,
- the barcode
- either INVESTIGATE or OK_TO_DELETE. 

E.g:
```2023-07-06T15:41:51,709 [list-all-jms-ef-responses.sh] INFO  851960.1688648406753.0 REJECTED	 XBZ74XOB INVESTIGATE```

If the barcode is not found on the EWF admin website or there is already a response 
with a status that differs from the status (ACCEPTED or REJECTED) inside the JMS message, then INVESTIGATE will be shown, and it is not safe to delete the message.
If the barcode is found and the response on the admin website is the same, then OK_TO_DELETE will be shown, and the message can usually be deleted without any issues.


### reprocess-jms.sh

This is run when there is a need to move JMS messages from one queue to another across a range of WebLogic servers.

The following parameters are required, in this order:

- The name of the queue to move messages from, e.g. uk.gov.ch.chips.jms.EfilingRequestErrorQueue
- The name of the queue to move messages to, e.g. uk.gov.ch.chips.jms.EfilingRequestQueue
- The number of messages to move, e.g. 500 

For example:
./reprocess-jms.sh uk.gov.ch.chips.jms.EfilingRequestErrorQueue uk.gov.ch.chips.jms.EfilingRequestQueue 500

The script moves messages on every one of the servers that are listed in environment variables that start with the prefix `JMS_SERVER_URL_`

For example, if the following environment variables were defined, the script would move messages on both these servers:

    JMS_SERVER_URL_1=t3s://chips-ef-batch0.heritage.aws.internal:21031|JMSServer1
    JMS_SERVER_URL_2=t3s://chips-ef-batch1.heritage.aws.internal:21031|JMSServer1


### resend-response-jms.sh

This is run when there is a need to resend an accept respone to the EWF or XML service.  The script injects a new JMS response message into the EfilingQueue queue, based on a supplied xml file containing the data from the CHIPS TRANSACTION_DOC_XML table.

The following parameters are required:

- The path of the xml file 
- The status of the response to send, such as "accept" or "reject"

For example:
./resend-response-jms.sh ./a.xml reject

The script injects the JMS message into the JMS server that is set in the environment variable `JMS_SERVER_URL_1`


### inject-jms.sh
This is intended to be called by other scripts and not run directly.  It is a wrapper around the Java class that is used to inject a JMS message into the EfilingQueue queue.


### list-jms.sh
This is intended to be called by other scripts and not run directly.  It is a wrapper around the Java class that is used to list JMS messages within a queue.


### move-jms.sh
This is intended to be called by other scripts and not run directly.  It is a wrapper around the Java class that is used to move JMS messages between queues.


