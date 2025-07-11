FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:1.2.5

ENV ORACLE_HOME=/apps/oracle \
    ARTIFACTORY_BASE_URL=https://artifactory.companieshouse.gov.uk/artifactory/virtual-release

RUN yum -y install gettext && \
    yum -y install cronie && \
    yum -y install oracle-instantclient-release-el7 && \
    yum -y install oracle-instantclient-basic && \
    yum -y install oracle-instantclient-sqlplus && \
    yum -y install https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm && \
    yum -y install msmtp && \
    yum -y install xmlstarlet && \
    yum -y install dos2unix && \
    yum -y install jq && \
    yum -y install openssh-clients && \
    yum -y install ftp && \
    yum clean all && \
    rm -rf /var/cache/yum

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
    curl ${ARTIFACTORY_BASE_URL}/org/apache/logging/log4j/log4j-api/2.21.1/log4j-api-2.21.1.jar -o log4j-api.jar && \    
    curl ${ARTIFACTORY_BASE_URL}/org/apache/logging/log4j/log4j-core/2.21.1/log4j-core-2.21.1.jar -o log4j-core.jar && \        
    curl ${ARTIFACTORY_BASE_URL}/org/apache/logging/log4j/log4j-1.2-api/2.21.1/log4j-1.2-api-2.21.1.jar -o log4j-1.2-api.jar && \        
    curl ${ARTIFACTORY_BASE_URL}/org/springframework/spring/2.0.7/spring-2.0.7.jar -o spring.jar && \
    curl ${ARTIFACTORY_BASE_URL}/commons-logging/commons-logging/1.0.4/commons-logging-1.0.4.jar -o commons-logging.jar && \
    curl ${ARTIFACTORY_BASE_URL}/com/thoughtworks/xstream/xstream/1.4.3/xstream-1.4.3.jar -o xstream.jar && \
    curl ${ARTIFACTORY_BASE_URL}/commons-lang/commons-lang/2.5/commons-lang-2.5.jar -o commons-lang.jar && \
    curl ${ARTIFACTORY_BASE_URL}/cglib/cglib-nodep/2.1_3/cglib-nodep-2.1_3.jar -o cglib-nodep.jar && \
    curl ${ARTIFACTORY_BASE_URL}/joda-time/joda-time/2.9.1/joda-time-2.9.1.jar -o joda-time.jar && \
    curl ${ARTIFACTORY_BASE_URL}/com/oracle/ojdbc8/12.2.1.4/ojdbc8-12.2.1.4.jar -o ojdbc8.jar && \
    curl ${ARTIFACTORY_BASE_URL}/com/oracle/weblogic/wlfullclient/12.2.1.4/wlfullclient-12.2.1.4.jar -o wlfullclient.jar && \
    curl ${ARTIFACTORY_BASE_URL}/org/jdom/jdom/1.1/jdom-1.1.jar -o jdom.jar && \
    curl ${ARTIFACTORY_BASE_URL}/javax/ws/rs/javax.ws.rs-api/2.1.1/javax.ws.rs-api-2.1.1.jar -o javax.ws.rs-api.jar && \ 
    curl ${ARTIFACTORY_BASE_URL}/javax/jms/jms-api/1.1-rev-1/jms-api-1.1-rev-1.jar -o jms-api.jar && \
    curl ${ARTIFACTORY_BASE_URL}/jaxen/jaxen/1.1.6/jaxen-1.1.6.jar -o jaxen.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/jmstool/1.5.0/jmstool-1.5.0.jar -o jmstool.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/batch-manager/1.0.1/batch-manager-1.0.1.jar -o ../batchmanager/batch-manager.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/bulk-image-load/1.0.2/bulk-image-load-1.0.2.jar -o ../bulk-image-load/bulk-image-load.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/compliance-trigger/1.1.3/compliance-trigger-1.1.3.jar -o ../compliance-trigger/compliance-trigger.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/dissolution-certificate-producer/0.1.1/dissolution-certificate-producer-0.1.1.jar -o ../dissolution-certificate-producer/dissolution-certificate-producer.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/doc1-producer/1.8.1/doc1-producer-1.8.1.jar -o ../doc1-producer/doc1-producer.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/image-regeneration/1.2.6/image-regeneration-1.2.6.jar -o ../image-regeneration/image-regeneration.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/letter-producer/1.1.2/letter-producer-1.1.2.jar -o ../letter-producer/letter-producer.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/officer-bulk-process/1.0.7/officer-bulk-process-1.0.7.jar -o ../officer-bulk-process/officer-bulk-process.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/psc-pursuit-trigger/1.9.1/psc-pursuit-trigger-1.9.1.jar -o ../psc-pursuit-trigger/psc-pursuit-trigger.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/image-api-message-generator/1.0/image-api-message-generator-1.0.jar -o ../mid-to-chs/image-api-message-generator.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/image-sender/0.1.32/image-sender-0.1.32.jar -o image-sender.jar && \
    curl ${ARTIFACTORY_BASE_URL}/uk/gov/companieshouse/chips_common/0.0.0-alpha1/chips_common-0.0.0-alpha1.jar -o chips-common.jar && \
    chmod -R 750 ${ORACLE_HOME}/*

WORKDIR $ORACLE_HOME
USER root
CMD ["bash"]
