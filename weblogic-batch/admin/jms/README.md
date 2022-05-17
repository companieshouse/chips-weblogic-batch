
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

    
### list-jms.sh
This is intended to be called by other scripts and not run directly.  It is a wrapper around the Java class that is used to list JMS messages within a queue.

### move-jms.sh
This is intended to be called by other scripts and not run directly.  It is a wrapper around the Java class that is used to move JMS messages between queues.


