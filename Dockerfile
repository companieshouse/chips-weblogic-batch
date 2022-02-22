FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:1.2.0

ENV ORACLE_HOME=/apps/oracle \
    ARTIFACTORY_BASE_URL=http://repository.aws.chdev.org:8081/artifactory

RUN yum -y install gettext && \
    yum -y install cronie && \
    yum -y install oracle-instantclient-release-el7 && \
    yum -y install oracle-instantclient-basic && \
    yum -y install oracle-instantclient-sqlplus && \
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum -y install msmtp && \
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
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/org/springframework/spring/2.0.7/spring-2.0.7.jar -o spring.jar && \
    curl ${ARTIFACTORY_BASE_URL}/virtual-release/commons-logging/commons-logging/1.0.4/commons-logging-1.0.4.jar -o commons-logging.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/com/oracle/ojdbc8/12.2.1.4/ojdbc8-12.2.1.4.jar -o ojdbc8.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/com/oracle/weblogic/wlfullclient/12.2.1.4/wlfullclient-12.2.1.4.jar -o wlfullclient.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/chaps/jms/jmstool/0.0.1/jmstool-0.0.1.jar -o jmstool.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/batch-manager/1.0.1/batch-manager-1.0.1.jar -o ../batchmanager/batch-manager.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/psc-pursuit-trigger/1.9.0/psc-pursuit-trigger-1.9.0.jar -o ../psc-pursuit-trigger/psc-pursuit-trigger.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/bulk-image-load/1.0.2/bulk-image-load-1.0.2.jar -o ../bulk-image-load/bulk-image-load.jar && \
    chmod -R 750 ${ORACLE_HOME}/*

WORKDIR $ORACLE_HOME
USER root
CMD ["bash"]
