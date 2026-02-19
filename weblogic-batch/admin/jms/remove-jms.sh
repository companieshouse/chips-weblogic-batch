#!/bin/bash

# =============================================================================
#
#  This script invokes the Java class chaps.jms.RemoveJMSMessages to move JMS 
#  messages from one queue to another.
# 
#  The expected parameters for chaps.jms.RemoveJMSMessages are, in order:
#
#  JMS SERVER NAME@SOURCE QUEUE - the queue to remove messages from, e.g. JMSServer1@uk.gov.ch.chips.jms.EfilingRequestErrorQueue
#  JMS SERVER URL - the t3 or t3s URL for the WebLogic server, e.g. t3s://1.2.3.4:1234
#  USERNAME - e.g. weblogic
#  PASSWORD - e.g. password
#  NUMBER OF MESSAGES - the number of messages to move, e.g. 100
#
#  This script is intended to be called from another wrapper script and its main
#  job is to set the CLASSPATH and any Java commandline parameters.
#  
# =============================================================================

LIBS=/apps/oracle/libs
CLASSPATH=${LIBS}/jmstool.jar:${LIBS}/log4j-1.2-api.jar:${LIBS}/log4j-api.jar:${LIBS}/log4j-core.jar:${LIBS}/jms-api.jar:${LIBS}/wlthint3client.jar:${LIBS}/jdom.jar:${LIBS}/chips-common.jar:${LIBS}/com.bea.core.jatmi.jar:${LIBS}/image-sender.jar

/usr/java/jdk/bin/java -cp ${CLASSPATH} -Dweblogic.security.SSL.ignoreHostnameVerification=true -Dweblogic.MaxMessageSize=100000000 chaps.jms.RemoveJMSMessages $*
