#!/bin/bash

echo `date` Starting java ${0}

/usr/java/jdk-8/bin/java -Din=mid-to-chs -cp $CLASSPATH -Dlog4j.configuration=log4jconfig.xml uk/gov/companieshouse/messagegenerator/ImageApiMessageGeneratorRunner ./image-api-message-generator.properties $1
if [ $? -gt 0 ]; then
        echo "Non-zero exit code for mid_to_chs java execution"
        exit 1
fi
