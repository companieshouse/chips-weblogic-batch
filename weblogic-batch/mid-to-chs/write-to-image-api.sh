#!/bin/bash

echo
echo `date` Starting java ${0}
echo

/usr/java/jdk-8/bin/java -Din=mid-to-chs -cp $CLASSPATH -Dlog4j.configuration=log4j.xml uk/gov/companieshouse/messagegenerator/ImageApiMessageGeneratorRunner ./image-api-message-generator.properties $1
if [ $? -gt 0 ]; then
        f_logError "Non-zero exit code for mid_to_chs java execution"
        exit 1
fi
