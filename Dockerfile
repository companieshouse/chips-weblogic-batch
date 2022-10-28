FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:1.2.1

ENV ORACLE_HOME=/apps/oracle \
    ARTIFACTORY_BASE_URL=http://repository.aws.chdev.org:8081/artifactory

RUN yum -y install gettext && \
    yum -y install cronie && \
    yum -y install oracle-instantclient-release-el7 && \
    yum -y install oracle-instantclient-basic && \
    yum -y install oracle-instantclient-sqlplus && \
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum -y install msmtp && \
    yum -y install xmlstarlet && \
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
    cd ${ORACLE_HOME}/libs && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/log4j/log4j/1.2.14/log4j-1.2.14.jar -o log4j.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/org/apache/logging/log4j/log4j-api/2.17.1/log4j-api-2.17.1.jar -o log4j-api.jar && \    
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/org/apache/logging/log4j/log4j-core/2.17.1/log4j-core-2.17.1.jar -o log4j-core.jar && \        
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/org/apache/logging/log4j/log4j-1.2-api/2.17.1/log4j-1.2-api-2.17.1.jar -o log4j-1.2-api.jar && \        
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/org/springframework/spring/2.0.7/spring-2.0.7.jar -o spring.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/commons-logging/commons-logging/1.0.4/commons-logging-1.0.4.jar -o commons-logging.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/com/thoughtworks/xstream/xstream/1.4.3/xstream-1.4.3.jar -o xstream.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/commons-lang/commons-lang/2.5/commons-lang-2.5.jar -o commons-lang.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/cglib/cglib-nodep/2.1_3/cglib-nodep-2.1_3.jar -o cglib-nodep.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/joda-time/joda-time/2.9.1/joda-time-2.9.1.jar -o joda-time.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/com/oracle/ojdbc8/12.2.1.4/ojdbc8-12.2.1.4.jar -o ojdbc8.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/com/oracle/weblogic/wlfullclient/12.2.1.4/wlfullclient-12.2.1.4.jar -o wlfullclient.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/org/jdom/jdom/1.1/jdom-1.1.jar -o jdom.jar && \
    curl ${ARTIFACTORY_BASE_URL}/libs-release/javax/jms/jms-api/1.1-rev-1/jms-api-1.1-rev-1.jar -o jms-api.jar && \
    curl ${ARTIFACTORY_BASE_URL}/libs-release/jaxen/jaxen/1.1.6/jaxen-1.1.6.jar -o jaxen.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/chaps/jms/jmstool/0.0.3/jmstool-0.0.3.jar -o jmstool.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/batch-manager/1.0.1/batch-manager-1.0.1.jar -o ../batchmanager/batch-manager.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/bulk-image-load/1.0.2/bulk-image-load-1.0.2.jar -o ../bulk-image-load/bulk-image-load.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/compliance-trigger/1.1.2/compliance-trigger-1.1.2.jar -o ../compliance-trigger/compliance-trigger.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/dissolution-certificate-producer/1.0.0-rc2/dissolution-certificate-producer-1.0.0-rc2.jar -o ../dissolution-certificate-producer/dissolution-certificate-producer.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/doc1-producer/1.8.1/doc1-producer-1.8.1.jar -o ../doc1-producer/doc1-producer.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/image-regeneration/1.2.5/image-regeneration-1.2.5.jar -o ../image-regeneration/image-regeneration.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/letter-producer/1.1.1/letter-producer-1.1.1.jar -o ../letter-producer/letter-producer.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/officer-bulk-process/1.0.7/officer-bulk-process-1.0.7.jar -o ../officer-bulk-process/officer-bulk-process.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/psc-pursuit-trigger/1.9.1/psc-pursuit-trigger-1.9.1.jar -o ../psc-pursuit-trigger/psc-pursuit-trigger.jar && \
    chmod -R 750 ${ORACLE_HOME}/*

WORKDIR $ORACLE_HOME
USER root
CMD ["bash"]
