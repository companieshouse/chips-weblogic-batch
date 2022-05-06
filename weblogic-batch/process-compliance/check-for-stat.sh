#!/bin/bash
cd ${0%/*}

#Get todays date for grep below and make sure folder has this date - avoids processing yesterday's
DATE=`date +%Y-%m-%d`

BATCH_FOLDER="/apps/oracle/input-output"

LETTERPRODUCEROUTPUTROOT=${BATCH_FOLDER}/letterProducerOutput

MOSTRECENTLETTERPRODUCERDIR=`ls -rt1 ${LETTERPRODUCEROUTPUTROOT} | grep -v "completed" | grep -v "failure" | grep $DATE | tail -1`

if [ -z ${MOSTRECENTLETTERPRODUCERDIR} ]; then
  echo "Cannot identify most recent LetterProducer output directory.  Please investigate."
  exit 2
fi

if [ -f ${LETTERPRODUCEROUTPUTROOT}/${MOSTRECENTLETTERPRODUCERDIR}/stat.txt ]; then
  echo ${LETTERPRODUCEROUTPUTROOT}/${MOSTRECENTLETTERPRODUCERDIR}
  exit 0
else
  ls -la ${LETTERPRODUCEROUTPUTROOT}/${MOSTRECENTLETTERPRODUCERDIR}/stat.txt
  exit 1
fi
