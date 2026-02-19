FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:2.0.3 AS builder

# The ARGS are not retained in the final image, due to using a multi-stage build.
ARG ARTIFACTORY_URL
ARG ARTIFACTORY_USERNAME
ARG ARTIFACTORY_PASSWORD

ENV ORACLE_HOME=/apps/oracle \
    ARTIFACTORY_BASE_URL=${ARTIFACTORY_URL}/virtual-release

RUN mkdir -p /apps && \
    chmod a+xr /apps && \
    useradd -d ${ORACLE_HOME} -m -s /bin/bash weblogic

USER weblogic

# Copy all batch jobs to ORACLE_HOME
COPY --chown=weblogic weblogic-batch ${ORACLE_HOME}/

# Download the batch libs and set permission on scripts
RUN mkdir -p ${ORACLE_HOME}/libs && \
    mkdir -p ${ORACLE_HOME}/.ssh && \
    cd ${ORACLE_HOME}/libs && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/apache/logging/log4j/log4j-api/2.21.1/log4j-api-2.21.1.jar -o log4j-api.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/apache/logging/log4j/log4j-core/2.21.1/log4j-core-2.21.1.jar -o log4j-core.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/apache/logging/log4j/log4j-1.2-api/2.21.1/log4j-1.2-api-2.21.1.jar -o log4j-1.2-api.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/springframework/spring/2.0.7/spring-2.0.7.jar -o spring.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/commons-logging/commons-logging/1.0.4/commons-logging-1.0.4.jar -o commons-logging.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/thoughtworks/xstream/xstream/1.4.3/xstream-1.4.3.jar -o xstream.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/commons-lang/commons-lang/2.5/commons-lang-2.5.jar -o commons-lang.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/cglib/cglib-nodep/2.1_3/cglib-nodep-2.1_3.jar -o cglib-nodep.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/joda-time/joda-time/2.9.1/joda-time-2.9.1.jar -o joda-time.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/oracle/database/jdbc/ojdbc11/23.9.0.25.07/ojdbc11-23.9.0.25.07.jar -o ojdbc11.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/oracle/weblogic/wlthint3client/14.1.2.0/wlthint3client-14.1.2.0.jar -o wlthint3client.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/bea/core/management/jmx/14.1.2.0/jmx-14.1.2.0.jar -o com.bea.core.management.jmx.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/bea/core/datasource6/14.1.2.0/datasource6-14.1.2.0.jar -o com.bea.core.datasource6.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/bea/core/resourcepool/14.1.2.0/resourcepool-14.1.2.0.jar -o com.bea.core.resourcepool.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/oracle/weblogic/jdbc/14.1.2.0/jdbc-14.1.2.0.jar -o com.oracle.weblogic.jdbc.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/oracle/weblogic/management/mbeanservers/14.1.2.0/mbeanservers-14.1.2.0.jar -o com.oracle.weblogic.management.mbeanservers.jar&& \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/oracle/weblogic/jms/14.1.2.0/jms-14.1.2.0.jar -o com.oracle.weblogic.jms.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/bea/core/utils/14.1.2.0/utils-14.1.2.0.jar -o com.bea.core.utils.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/oracle/weblogic/management/core/api/14.1.2.0/api-14.1.2.0.jar -o com.oracle.weblogic.management.core.api.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/bea/core/weblogic/lifecycle/14.1.2.0/lifecycle-14.1.2.0.jar -o com.bea.core.weblogic.lifecycle.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/oracle/weblogic/management/base/14.1.2.0/base-14.1.2.0.jar -o com.oracle.weblogic.management.base.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/bea/core/management/core/14.1.2.0/core-14.1.2.0.jar -o com.bea.core.management.core.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/oracle/weblogic/security/14.1.2.0/security-14.1.2.0.jar -o com.oracle.weblogic.security.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/oracle/weblogic/management/config/api/14.1.2.0/api-14.1.2.0.jar -o com.oracle.weblogic.management.config.api.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/com/bea/core/jatmi/14.1.2.0/jatmi-14.1.2.0.jar -o com.bea.core.jatmi.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/jdom/jdom/1.1/jdom-1.1.jar -o jdom.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/javax/ws/rs/javax.ws.rs-api/2.1.1/javax.ws.rs-api-2.1.1.jar -o javax.ws.rs-api.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/javax/jms/jms-api/1.1-rev-1/jms-api-1.1-rev-1.jar -o jms-api.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/jaxen/jaxen/1.1.6/jaxen-1.1.6.jar -o jaxen.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/jmstool/1.5.0/jmstool-1.5.0.jar -o jmstool.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/batch-manager/2.0.3/batch-manager-2.0.3.jar -o ../batchmanager/batch-manager.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/bulk-image-load/1.0.2/bulk-image-load-1.0.2.jar -o ../bulk-image-load/bulk-image-load.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/compliance-trigger/1.1.4/compliance-trigger-1.1.4.jar -o ../compliance-trigger/compliance-trigger.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/dissolution-certificate-producer/0.1.1/dissolution-certificate-producer-0.1.1.jar -o ../dissolution-certificate-producer/dissolution-certificate-producer.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/doc1-producer/1.8.1/doc1-producer-1.8.1.jar -o ../doc1-producer/doc1-producer.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/image-regeneration/1.2.6/image-regeneration-1.2.6.jar -o ../image-regeneration/image-regeneration.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/letter-producer/1.1.3/letter-producer-1.1.3.jar -o ../letter-producer/letter-producer.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/officer-bulk-process/1.0.8/officer-bulk-process-1.0.8.jar -o ../officer-bulk-process/officer-bulk-process.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/psc-pursuit-trigger/2.1.1/psc-pursuit-trigger-2.1.1.jar -o ../psc-pursuit-trigger/psc-pursuit-trigger.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/image-api-message-generator/1.0/image-api-message-generator-1.0.jar -o ../mid-to-chs/image-api-message-generator.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/image-sender/0.1.32/image-sender-0.1.32.jar -o image-sender.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/chips_common/0.0.0-alpha1/chips_common-0.0.0-alpha1.jar -o chips-common.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/springframework/spring-core/4.3.30.RELEASE/spring-core-4.3.30.RELEASE.jar -o spring-core-4.3.30.RELEASE.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/springframework/spring-beans/4.3.30.RELEASE/spring-beans-4.3.30.RELEASE.jar -o spring-beans-4.3.30.RELEASE.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/springframework/spring-context/4.3.30.RELEASE/spring-context-4.3.30.RELEASE.jar -o spring-context-4.3.30.RELEASE.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/springframework/spring-jms/4.3.30.RELEASE/spring-jms-4.3.30.RELEASE.jar -o spring-jms-4.3.30.RELEASE.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/springframework/spring-aop/4.3.30.RELEASE/spring-aop-4.3.30.RELEASE.jar -o spring-aop-4.3.30.RELEASE.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/springframework/spring-expression/4.3.30.RELEASE/spring-expression-4.3.30.RELEASE.jar -o spring-expression-4.3.30.RELEASE.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/javax/jms/javax.jms-api/2.0.1/javax.jms-api-2.0.1.jar -o javax.jms-api-2.0.1.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/apache/logging/log4j/log4j-api/2.25.3/log4j-api-2.25.3.jar -o log4j-api-2.25.3.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/apache/logging/log4j/log4j-core/2.25.3/log4j-core-2.25.3.jar -o log4j-core-2.25.3.jar && \
    curl -L -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" ${ARTIFACTORY_BASE_URL}/org/apache/logging/log4j/log4j-jcl/2.25.3/log4j-jcl-2.25.3.jar -o log4j-jcl-2.25.3.jar && \
    chmod -R 750 ${ORACLE_HOME}/*

FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:2.0.3

ENV ORACLE_HOME=/apps/oracle
 
RUN yum -y install gettext && \
    yum -y install cronie && \
    yum -y install oracle-instantclient-release-el8 && \
    yum -y install oracle-instantclient-basic && \
    yum -y install oracle-instantclient-sqlplus && \
    yum -y install epel-release && \
    yum -y install msmtp && \
    yum -y install xmlstarlet && \
    yum -y install dos2unix && \
    yum -y install jq && \
    yum -y install openssh-clients && \
    yum -y install ftp && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN mkdir -p /apps && chmod a+xr /apps && useradd -d ${ORACLE_HOME} -m -s /bin/bash weblogic
USER weblogic

COPY --from=builder --chown=weblogic ${ORACLE_HOME} ${ORACLE_HOME}

WORKDIR $ORACLE_HOME
USER root
CMD ["bash"]
