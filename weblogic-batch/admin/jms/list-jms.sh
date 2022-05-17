#!/bin/bash

# =============================================================================
#
#  This script invokes the Java class chaps.jms.ListJMSMessages to list JMS 
#  messages held in a queue.
# 
#  The expected parameters for chaps.jms.ListJMSMessages are, in order:
#
#  JMS SERVER NAME@QUEUE - the queue to list messages in, e.g. JMSServer1@uk.gov.ch.chips.jms.EfilingRequestErrorQueue
#  JMS SERVER URL - the t3 or t3s URL for the WebLogic server, e.g. t3s://1.2.3.4:1234
#  USERNAME - e.g. weblogic
#  PASSWORD - e.g. password
#
#  This script is intended to be called from another wrapper script and its main
#  job is to set the CLASSPATH and any Java commandline parameters.
#  
# =============================================================================

LIBS=/apps/oracle/libs
CLASSPATH=${LIBS}/jmstool.jar:${LIBS}/log4j.jar:${LIBS}/jms-api.jar:${LIBS}/wlfullclient.jar:${LIBS}/jdom.jar

/usr/java/jdk-8/bin/java -cp ${CLASSPATH} -Dweblogic.security.SSL.ignoreHostnameVerification=true -Dweblogic.MaxMessageSize=100000000 chaps.jms.ListJMSMessages $*
