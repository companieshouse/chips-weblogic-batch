FROM 300288021642.dkr.ecr.eu-west-2.amazonaws.com/ch-serverjre:1.2.0

ENV ORACLE_HOME=/apps/oracle \
    ARTIFACTORY_BASE_URL=http://repository.aws.chdev.org:8081/artifactory

RUN yum -y install gettext && \
    yum -y install cronie && \
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
    curl ${ARTIFACTORY_BASE_URL}/libs-release/log4j/log4j/1.2.14/log4j-1.2.14.jar -o log4j.jar && \
    curl ${ARTIFACTORY_BASE_URL}/libs-release/org/springframework/spring/2.0.7/spring-2.0.7.jar -o spring.jar && \
    curl ${ARTIFACTORY_BASE_URL}/libs-release/commons-logging/commons-logging/1.0.4/commons-logging-1.0.4.jar -o commons-logging.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/com/oracle/ojdbc8/12.2.1.4/ojdbc8-12.2.1.4.jar -o ojdbc8.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/com/oracle/weblogic/wlthint3client/12.2.1.4/wlthint3client-12.2.1.4.jar -o wlthint3client.jar && \
    curl ${ARTIFACTORY_BASE_URL}/local-ch-release/uk/gov/companieshouse/batch-manager/1.0.1/batch-manager-1.0.1.jar -o ../batchmanager/batch-manager.jar
                   
    chmod -R 750 ${ORACLE_HOME}/*

WORKDIR $ORACLE_HOME
USER root
CMD ["bash"]
