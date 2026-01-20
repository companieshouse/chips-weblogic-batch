#!/bin/bash

# =============================================================================
#
#  This script invokes the Java class chaps.jms.InjectResponseJMSMessages to
#  insert an ACCEPT JMS message to the EfilingQueue based on an xml file.
#
#  The expected parameters for chaps.jms.InjectResponseJMSMessages are, in order:
#
#  PATH TO XML FILE - the file to create the JMS message from
#  STATUS - accept or reject
#  JMS SERVER NAME@$DESTINATION QUEUE - the queue to inject the message into, e.g. JMSServer1@uk.gov.ch.chips.jms.EfilingQueue
#  JMS SERVER URL - the t3 or t3s URL for the WebLogic server, e.g. t3s://1.2.3.4:1234
#  USERNAME - e.g. weblogic
#  PASSWORD - e.g. password
#
#  This script is intended to be called from another wrapper script and its main
#  job is to set the CLASSPATH and any Java commandline parameters.
#
# =============================================================================

LIBS=/apps/oracle/libs
CLASSPATH=${LIBS}/jmstool.jar:${LIBS}/log4j-1.2-api.jar:${LIBS}/log4j-api.jar:${LIBS}/log4j-core.jar:${LIBS}/jms-api.jar:${LIBS}/wlthint3client.jar:${LIBS}/jdom.jar:${LIBS}/jaxen.jar:${LIBS}/chips-common.jar:${LIBS}/com.bea.core.jatmi.jar

/usr/java/jdk/bin/java -cp ${CLASSPATH} -Dweblogic.security.SSL.ignoreHostnameVerification=true -Dweblogic.MaxMessageSize=100000000 chaps.jms.InjectResponseJMSMessages $*