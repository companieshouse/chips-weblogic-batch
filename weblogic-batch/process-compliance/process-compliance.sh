#!/bin/bash

cd /apps/oracle/process-compliance

# load variables created from setCron script - being careful not to overwrite HOME as msmtp mail process uses it to find config
KEEP_HOME=${HOME}
source /apps/oracle/env.variables
HOME=${KEEP_HOME}

# create properties file and substitutes values
envsubst < process-compliance.properties.template > process-compliance.properties
source process-compliance.properties

# Set up mail config for msmtp & load alerting functions
envsubst < /apps/oracle/.msmtprc.template > /apps/oracle/.msmtprc
source /apps/oracle/scripts/alert_functions

# Setting up standard logging here, but task scripts also log separately using tee to duplicate the output
# set up logging
LOGS_DIR=../logs/process-compliance
mkdir -p ${LOGS_DIR}
LOG_FILE="${LOGS_DIR}/${HOSTNAME}-process-compliance-$(date +'%Y-%m-%d_%H-%M-%S').log"
source /apps/oracle/scripts/logging_functions

exec >> "${LOG_FILE}" 2>&1

PrintVar() {
  f_logInfo "RUN_COMPLIANCE=$RUN_COMPLIANCE"
  f_logInfo "RUN_LETTERPRODUCER=$RUN_LETTERPRODUCER"
  f_logInfo "RUN_DOC1=$RUN_DOC1"
  f_logInfo "RUN_AFP=$RUN_AFP"
}

f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
f_logInfo "Starting Compliance Process script." 

################################################################################
# Check / set environment variables
################################################################################

if [ -z ${INTERACTIVE} ]; then        # variable for auditing in logs
  INTERACTIVE="NO"
fi

#CHECK: If run_menu_interactive.sh  did not set the control variables, then set them now to YES. This default is to run everything.

if [ -z ${RUN_COMPLIANCE} ]; then
  RUN_COMPLIANCE="YES"
  f_logInfo "RUN_COMPLIANCE not set - setting to default YES" 
fi

if [ -z ${RUN_LETTERPRODUCER} ]; then
  RUN_LETTERPRODUCER="YES"
  f_logInfo "RUN_LETTERPRODUCER not set - setting to default YES" 
fi

if [ -z ${RUN_DOC1} ]; then
  RUN_DOC1="YES"
  f_logInfo "RUN_DOC1 not set - setting to default YES"
fi

if [ -z ${RUN_AFP} ]; then
  RUN_AFP="YES"
  f_logInfo "RUN_AFP not set - setting to default YES"
fi

if [ -z ${IGNORE_AFP_COUNT} ]; then
  IGNORE_AFP_COUNT="NO"
  f_logInfo "IGNORE_AFP_COUNT not set - setting to default NO"
fi

#CHECK: All expected env properties have been set?

if [[ -z ${BATCH_FOLDER} ]]; then
  f_logError "BATCH_FOLDER not set - please edit properties"  ; exit 1
fi
if [[ -z ${COMPLIANCE_TRIGGER_SCRIPT} ]]; then
  f_logError "COMPLIANCE_TRIGGER_SCRIPT not set - please edit properties"  ; exit 1
fi
if [[ -z ${LETTER_PRODUCER_SCRIPT} ]]; then
  f_logError "LETTER_PRODUCER_SCRIPT not set - please edit properties"  ; exit 1
fi
if [[ -z ${LETTER_PRODUCER_PROPERTIES} ]]; then
  f_logError "LETTER_PRODUCER_PROPERTIES not set - please edit properties"  ; exit 1
fi
if [[ -z ${DOC1_PRODUCER_SCRIPT} ]]; then
  f_logError "DOC1_PRODUCER_SCRIPT not set - please edit properties"  ; exit 1
fi
if [[ -z ${DOC1_PRODUCER_CONFIG} ]]; then
  f_logError "DOC1_PRODUCER_CONFIG not set - please edit properties"  ; exit 1
fi
if [[ -z ${DOC1_PRODUCER_PROPERTIES} ]]; then
  f_logError "DOC1_PRODUCER_CONFIG not set - please edit properties"  ; exit 1
fi
if [[ -z ${LETTER_CHECK_MAX} ]]; then
  f_logError "LETTER_CHECK_MAX not set - please edit properties"  ; exit 1
fi
if [[ -z ${LETTER_CHECK_PERIOD} ]]; then
  f_logError "LETTER_CHECK_PERIOD not set - please edit properties"  ; exit 1
fi
if [[ -z ${DOC1_GATEWAY_LOCATION_EW} ]]; then
  f_logError "DOC1_GATEWAY_LOCATION_EW not set - please edit properties"  ; exit 1
fi
if [[ -z ${ERROR_FILES} ]]; then
  f_logError "ERROR_FILES not set - please edit properties"  ; exit 1
fi
if [[ -z ${AFP_FILES} ]]; then
  f_logError "AFP_FILES not set - please edit properties"  ; exit 1
fi
if [[ -z ${AFP_INPUT_LOCATION} ]]; then
  f_logError "AFP_INPUT_LOCATION not set - please edit properties"  ; exit 1
fi
if [[ -z ${AFP_OUTPUT_LOCATION} ]]; then
  f_logError "AFP_OUTPUT_LOCATION not set - please edit properties"  ; exit 1
fi
if [[ -z ${SWIFTSORT_INPUT_LOCATION} ]]; then
  f_logError "SWIFTSORT_INPUT_LOCATION not set - please edit properties"  ; exit 1
fi
if [[ -z ${DOC1FILE_CH_ADDRESS_DIR} ]]; then
  f_logError "DOC1FILE_CH_ADDRESS_DIR not set - please edit properties"  ; exit 1
fi

###############################################################################
# BELOW HERE STARTS THE ACTION 
###############################################################################


###############################################################################
#Check that letteroutput directory can mount and be written to
###############################################################################
f_logInfo "Checking that letter output directory can mount and be written to." 
## not needed for test systems
./check-letter-dir-mounted.sh
if [ $? -gt 0 ]; then
  f_logError "letteroutput directory cannot be written to. Please investigate." 
  patrol_log_alert_chaps_f " `pwd`/`basename $0`: letteroutput directory cannot be written to. Please investigate."
  exit 1
fi

###############################################################################
#Logging
###############################################################################
f_logInfo "Is Interactive Mode on? ${INTERACTIVE}."  
f_logInfo "Here are the following control variable settings:"
PrintVar

###############################################################################
#Run Compliance Trigger
###############################################################################
if [ $RUN_COMPLIANCE = "YES" ] ; then

  f_logInfo "Launching compliancetrigger.." 
  $COMPLIANCE_TRIGGER_SCRIPT
  if [ $? -gt 0 ]; then
    f_logError "Compliance trigger exit code indicates failure.  Please investigate." 
    patrol_log_alert_chaps_f " `pwd`/`basename $0`: Compliance trigger exit code indicates failure.  Please investigate."
    exit 1
  fi
fi

###############################################################################
#Run LetterProducer and check
###############################################################################
if [ $RUN_LETTERPRODUCER = "YES" ] ; then

  f_logInfo "Launching LetterProducer.." 
  $LETTER_PRODUCER_SCRIPT
  if [ $? -gt 0 ]; then
    f_logError "LetterProducer exit code indicates failure.  Please investigate." 
    patrol_log_alert_chaps_f " `pwd`/`basename $0`: LetterProducer exit code indicates failure.  Please investigate."
    exit 1
  fi
  
  ## WAIT/CHECK: Has LetterProducer finished Phase 1 xml file generation (check for stat.txt file in most recent letter output folder)
  f_logInfo "Start waiting and checking for LetterProducer stats.txt.."

  CHECKFORSTATS=1
  CHECKCOUNT=${LETTER_CHECK_MAX}
  ## set the time to alert CHAPS if letterproducer is taking too long. 42 is 2.5 hours.
  ## this number counts DOWN, 23 will ring you at about 5:00
  ALERTIFRUNNINGSLOW=3

  while [ ${CHECKFORSTATS} -gt 0 ]
  do
    sleep ${LETTER_CHECK_PERIOD}

    # capture output to keep log tidy (not using log functions as eventually returning directory via echo)
    LATESTLETTEROUTPUTLOCATION=$(./check-for-stat.sh)
    CHECKFORSTATS=$?

    if [ ${CHECKCOUNT} -eq 0 ]; then
      ## We should never get here but alert if we loop after x hours
      f_logError "Maximum number of checks for stats.txt exceeded.  LETTER_CHECK_MAX is ${LETTER_CHECK_MAX}, LETTER_CHECK_PERIOD is ${LETTER_CHECK_PERIOD}seconds"
      f_logError "LetterProducer may have failed or may be overrunning as no recent stats.txt has been detected. Please investigate."
      patrol_log_alert_chaps_f " `pwd`/`basename $0`: LetterProducer may have failed or may be overrunning as no recent stats.txt has been detected. Please investigate."
      exit 1

    elif [ ${CHECKCOUNT} -eq ${ALERTIFRUNNINGSLOW} ]; then
      ## LetterProducer is running for more than x minutes, alert officer but keep program running. 
      f_logWarn "LetterProducer may be overrunning as no recent stats.txt has been detected. Please investigate."
      patrol_log_alert_chaps_f " `pwd`/`basename $0`: LetterProducer may be overrunning as no recent stats.txt has been detected. Please investigate."

    else

      if [ ${CHECKFORSTATS} -gt 0 ]; then
        if [ ${CHECKFORSTATS} -gt 1 ]; then
          # directory not found (yet?)
          f_logWarn "check-for-stat.sh cannot identify most recent LetterProducer output directory"
        fi
        ## no stat file found, letterproducer still working
        f_logInfo "No stat.txt file found yet. ${CHECKCOUNT} checks remaining with a wait of ${LETTER_CHECK_PERIOD} seconds between each."

        ## However, we need to check if JMS Message is gone. If theres an error in Weblogic like JTA timeout, no point looping so exit and alert.
        ../scripts/check-for-jms-message.sh ${JMS_LETTERPRODUCERQUEUE} "RUNNING"
        if [ $? -gt 0 ]; then
          f_logError "LetterProducer MDB message no longer processing in queue and no stat.txt found.  Please investigate."
          patrol_log_alert_chaps_f " `pwd`/`basename $0`: LetterProducer MDB message no longer processing in queue and no stat.txt found. Please investigate."
          exit 1
        fi
      fi
    fi

    CHECKCOUNT=$(( $CHECKCOUNT-1 ))
  done

  f_logInfo "stat.txt file found."
  
fi

## Make sure the LATESTLETTEROUTPUTLOCATION is set & check for errors
LATESTLETTEROUTPUTLOCATION=$(./check-for-stat.sh)

if [ $? -gt 0 ]; then
  f_logError "check-for-stat.sh exit code getting LATESTLETTEROUTPUTLOCATION indicates failure.  Please investigate."
  f_logError "check-for-stat.sh output was: $LATESTLETTEROUTPUTLOCATION"
  patrol_log_alert_chaps_f " `pwd`/`basename $0`: check-for-stat.sh  exit code getting LATESTLETTEROUTPUTLOCATION indicates failure.  Please investigate."
  exit 1
fi
f_logInfo "LATEST LETTER OUTPUT LOCATION IS $LATESTLETTEROUTPUTLOCATION"

## check dir exists
if [[ ! -d ${LATESTLETTEROUTPUTLOCATION} ]]; then
  f_logError "Doc1Producer LATESTLETTEROUTPUTLOCATION not a directory.  Please investigate."
  patrol_log_alert_chaps_f " `pwd`/`basename $0`:  Doc1Producer LATESTLETTEROUTPUTLOCATION not a directory.  Please investigate."
  exit 1
fi

###############################################################################
#Run Doc1Producer against doc1 generation location
###############################################################################
if [ $RUN_DOC1 = "YES" ] ; then

  f_logInfo "Launching Doc1Producer.." 
  DOC1OUTPUTLOCATION=`echo ${LATESTLETTEROUTPUTLOCATION} | sed -e 's/letterProducerOutput/doc1ProducerOutput/g'`/

  f_logInfo "Source is: ${LATESTLETTEROUTPUTLOCATION}" 
  f_logInfo "Destination is: ${DOC1OUTPUTLOCATION}" 

  $DOC1_PRODUCER_SCRIPT ${DOC1_PRODUCER_PROPERTIES} ${DOC1_PRODUCER_CONFIG} ${LATESTLETTEROUTPUTLOCATION} ${DOC1OUTPUTLOCATION}
  if [ $? -gt 0 ]; then
    f_logError "Doc1Producer exit code indicates failure.  Please investigate." 
    patrol_log_alert_chaps_f " `pwd`/`basename $0`:  Doc1Producer exit code indicates failure.  Please investigate."
    exit 1
  fi
  
  # CHG0047313 01/11/2019 begins
  # Fix to prevent letters with the CH default address being printed by APS and posted back to us.
  # These letters do, however, need to be processed by DOC1 because they need to be visible in SmartView.  So
  # the records containing the CH Default address are stripped from the DOC1 input files and written to an identical
  # file structure under a doc1ProducerOutput_ch_address directory.
  f_logInfo "DOC1OUTPUTLOCATION is now ${DOC1OUTPUTLOCATION}"
  DOC1FILELIST=`find ${DOC1OUTPUTLOCATION} -type f`
  f_logInfo "List of doc1 files after doc1Producer but before being passed to the DOC1 app is:"
  for DOC1FILE in ${DOC1FILELIST}; do
     f_logInfo "Doc1 file: $DOC1FILE"
  done

  #  DOC1FILE_CH_ADDRESS_DIR set in process.properties
  f_logInfo "DOC1FILE_CH_ADDRESS_DIR is ${DOC1FILE_CH_ADDRESS_DIR}"
  rm -rf $DOC1FILE_CH_ADDRESS_DIR
  for DOC1FILE in ${DOC1FILELIST}
    do
       DOC1FILE_CH_ADDRESS=`echo ${DOC1FILE} | sed -e 's?doc1ProducerOutput?doc1ProducerOutput_ch_address?g'`
       f_logInfo "DOC1FILE_CH_ADDRESS is $DOC1FILE_CH_ADDRESS"
       DIRPATH="`dirname $DOC1FILE_CH_ADDRESS`"
       f_logInfo "DIRPATH=$DIRPATH"
       mkdir -p "${DIRPATH}"
       # Only create output file if there are letters with the CH default address (ie don't create empty files)
       grep 'Companies House Default' $DOC1FILE >/dev/null && grep 'Companies House Default' $DOC1FILE > ${DOC1FILE_CH_ADDRESS}_CH_ADDRESS
	   grep -v "Companies House Default" ${DOC1FILE}  > ${DOC1FILE}_temp
	   mv ${DOC1FILE}_temp  ${DOC1FILE}
    done
   # CHG0047313 01/11/2019 ends

  
fi
###############################################################################
#Reformat and copy Doc1Producer output into transfer location -e.g. /Interfaces/doc1
###############################################################################
if [ $RUN_DOC1 = "YES" ] ; then
  f_logInfo "Renaming and copying doc1 output files to gateway nfs share.." 
  f_logInfo "Getting list of all output files" 
  OUTPUTFILELIST=`find ${DOC1OUTPUTLOCATION} -type f ! -size 0`
  for OUTPUTFILE in $OUTPUTFILELIST; do
     f_logInfo "Output file found: $OUTPUTFILE"
  done

  ## check dir exists
  if [[ ! -d ${DOC1OUTPUTLOCATION} ]]; then
    f_logError "Doc1Producer DOC1OUTPUTLOCATION not a directory. Do we have any letters? Please investigate."
    f_logError "DOC1OUTPUTLOCATION is ${DOC1OUTPUTLOCATION}"
    patrol_log_alert_chaps_f " `pwd`/`basename $0`:  Doc1Producer DOC1OUTPUTLOCATION not a directory.  Do we have any letters? Please investigate."
    email_CHAPS_group_f "Doc1Producer DOC1OUTPUTLOCATION not a directory" "Doc1Producer DOC1OUTPUTLOCATION not a directory. Possibly no Letters for DOC1.  Do we have any letters? Please investigate."
    exit 1
  fi

  ## check AFP input dir exists 
  if [[ ! -d ${AFP_INPUT_LOCATION} ]]; then
    f_logError "Doc1Producer AFP_INPUT_LOCATION not a directory. Is folder mapped correctly? Please investigate."
    f_logError "AFP_INPUT_LOCATION is ${AFP_INPUT_LOCATION}"
    patrol_log_alert_chaps_f " `pwd`/`basename $0`:  Doc1Producer APF_INPUT_LOCATION not a directory.  Do we have any letters? Please investigate."
    email_CHAPS_group_f "Doc1Producer AFP_INPUT_LOCATION not a directory" "Doc1Producer AFP_INPUT_LOCATION not a directory. Possibly no Letters for DOC1.  Do we have any letters? Please investigate."
    exit 1
  fi

  ## check AFP output dir exists
  if [[ ! -d ${AFP_OUTPUT_LOCATION} ]]; then
    f_logError "Doc1Producer AFP_OUTPUT_LOCATION not a directory. Is folder mapped correctly? Please investigate."
    f_logError "AFP_OUTPUT_LOCATION is ${AFP_OUTPUT_LOCATION}"
    patrol_log_alert_chaps_f " `pwd`/`basename $0`:  Doc1Producer APF_OUTPUT_LOCATION not a directory.  Do we have any letters? Please investigate."
    email_CHAPS_group_f "Doc1Producer AFP_OUTPUT_LOCATION not a directory" "Doc1Producer AFP_OUTPUT_LOCATION not a directory. Possibly no Letters for DOC1.  Do we have any letters? Please investigate."
    exit 1
  fi

  #Counter to count number of AFP files being processed
  AFP_FILE_COUNT=0

  for OUTPUTFILE in ${OUTPUTFILELIST}
  do
     OUTPUTFILENAME=${OUTPUTFILE##*/}

     #Is the output file an error file?
     ERRORFILEFLAG="FALSE"
     f_logInfo "----------" 
     f_logInfo "Checking ${OUTPUTFILE}" 
     for ERRORFILE in ${ERROR_FILES}
     do
        if [ ${OUTPUTFILENAME} = ${ERRORFILE} ]; then
           f_logInfo "error file match...against ${ERRORFILE}"
           ERRORFILEFLAG="TRUE"
        fi
     done
     f_logInfo "ERRORFILEFLAG=${ERRORFILEFLAG}."

     if [ ${ERRORFILEFLAG} = "FALSE" ]; then
    
        if [ "$OUTPUTFILENAME" = "NewDirCOMPLETT.txt" ] 
        then
            f_logInfo "Moving England/Wales New Director files to $SWIFTSORT_INPUT_LOCATION"
	          f_logInfo "moving $OUTPUTFILE to $SWIFTSORT_INPUT_LOCATION"
            mv $OUTPUTFILE $SWIFTSORT_INPUT_LOCATION
            continue
        fi

        if [ "$OUTPUTFILENAME" = "NewDirSCOTDOC1.txt" ] 
        then
            f_logInfo "Moving Scottish New Director files to $SWIFTSORT_INPUT_LOCATION"
	          f_logInfo "moving $OUTPUTFILE to $SWIFTSORT_INPUT_LOCATION"
            mv $OUTPUTFILE $SWIFTSORT_INPUT_LOCATION
            continue
        fi

        if [ "$OUTPUTFILENAME" = "NewDirNICOMP.txt" ] 
        then
            f_logInfo "Moving Irish New Director files to $SWIFTSORT_INPUT_LOCATION"
	          f_logInfo "moving $OUTPUTFILE to $SWIFTSORT_INPUT_LOCATION"
            mv $OUTPUTFILE $SWIFTSORT_INPUT_LOCATION
            continue
        fi

        #Is the output file being sent to DOC1 windows server?
        AFPFILEFLAG="FALSE"
        for AFPFILE in ${AFP_FILES}
        do
           if [ ${OUTPUTFILENAME} = ${AFPFILE} ]; then
              f_logInfo "AFP file match...against ${AFPFILE}"
              AFPFILEFLAG="TRUE"
           fi
        done
        f_logInfo "AFPFILEFLAG=${AFPFILEFLAG}." 

        #Moved code below before check for AFP files as merge should happen regardless
        #SMC DEF49EW must be merged with COMPLETT before copying to the gateway
        if [ ${OUTPUTFILENAME} = "COMPLETT" ]; then
           if [ -f "${DOC1OUTPUTLOCATION}CHLETTER/DEF49EW" ]; then
              f_logInfo "We are into COMPLETT, copying DEF49W into COMPLETT"
              echo '' >> ${OUTPUTFILE}
              cat ${DOC1OUTPUTLOCATION}CHLETTER/DEF49EW >> ${OUTPUTFILE}
           fi
        fi

        #SL WDEF49EW must be merged with WCOMPLETT before copying to the gateway
        if [ ${OUTPUTFILENAME} = "WCOMPLETT" ]; then
           if [ -f "${DOC1OUTPUTLOCATION}CHLETTER/WDEF49EW" ]; then
              f_logInfo "We are into WCOMPLETT, copying WDEF49W into WCOMPLETT"
              echo '' >> ${OUTPUTFILE}
              cat ${DOC1OUTPUTLOCATION}CHLETTER/WDEF49EW >> ${OUTPUTFILE}
           fi
        fi

        #SL NI equivalent of the above                                        
        if [ ${OUTPUTFILENAME} = "NICOMP" ]; then
           if [ -f "${DOC1OUTPUTLOCATION}NICOMP/DOC1DATA/NIDEF49" ]; then
              f_logInfo "We are into NICOMP, copying NIDEF49 into NICOMP"
              echo '' >> ${OUTPUTFILE}
              cat ${DOC1OUTPUTLOCATION}NICOMP/DOC1DATA/NIDEF49 >> ${OUTPUTFILE}
           fi
        fi

        #SMC CERTSSC.TXT file must have CERTSSC_DEF6.TXT appended before copying to the gateway
        if [ ${OUTPUTFILENAME} = "CERTSSC.TXT" ]; then
           if [ -f "${DOC1OUTPUTLOCATION}SVOLCERT/DOC1DATA/CERTSSC_DEF6.TXT" ]; then
              f_logInfo "We are into CERTSSC.TXT, copying CERTSSC_DEF6.TXT to the end of CERTSSC.TXT"
              echo '' >> ${OUTPUTFILE}
              cat ${DOC1OUTPUTLOCATION}SVOLCERT/DOC1DATA/CERTSSC_DEF6.TXT >> ${OUTPUTFILE}
           fi
        fi

        #Process the Non-AFP file (Going directly to the Gateway)
        if [ ${AFPFILEFLAG} = "FALSE" ]; then
           DOC1_GATEWAY_LOCATION=${DOC1_GATEWAY_LOCATION_EW}

           #Alter the destination filename, if needed, to avoid overwriting any existing files with the same name
           OUTPUTFILENAMEDESTINATION=${OUTPUTFILENAME}
           COUNTER=1
           if [ -f ${DOC1_GATEWAY_LOCATION}/${OUTPUTFILENAMEDESTINATION} ]; then
              OUTPUTFILENAMEDESTINATION=${OUTPUTFILENAMEDESTINATION}.${COUNTER}  
  
              while [ -f ${DOC1_GATEWAY_LOCATION}/${OUTPUTFILENAMEDESTINATION} ]
              do
                 ((COUNTER=COUNTER + 1))
                 OUTPUTFILENAMEDESTINATION=${OUTPUTFILENAMEDESTINATION%.*}.${COUNTER}
              done
           fi
  
           #Do the copy to the gateway
           #SMC HSOL1 must be duplicated as a HS1COPY file before copying to the gateway
           if [ ${OUTPUTFILENAME} = "HSOL1" ]; then
                 f_logInfo "Creating HS1COPY file from HSOL1 file"
                 f_logInfo "Writing ${DOC1_GATEWAY_LOCATION}/HS1COPY."
                 cp ${OUTPUTFILE} ${DOC1_GATEWAY_LOCATION}/HS1COPY 
           fi

           #SL  HSOL1W must be duplicated as HS1CPYW file before copying to the gateway
           if [ ${OUTPUTFILENAME} = "HSOL1W" ]; then
                 f_logInfo "Creating HS1CPYW file from HSOL1W file"
                 f_logInfo "Writing ${DOC1_GATEWAY_LOCATION}/HS1CPYW."
                 cp ${OUTPUTFILE} ${DOC1_GATEWAY_LOCATION}/HS1CPYW
           fi

           f_logInfo "Writing ${DOC1_GATEWAY_LOCATION}/${OUTPUTFILENAMEDESTINATION}."  

           cp ${OUTPUTFILE} ${DOC1_GATEWAY_LOCATION}/${OUTPUTFILENAMEDESTINATION} 
        else
           #Process AFP files...
           f_logInfo "Processing ${OUTPUTFILENAME} as AFP file."  

           #Increment count of AFP files (To check output file later) 
           ((AFP_FILE_COUNT=AFP_FILE_COUNT + 1))

           f_logInfo "Writing ${AFP_INPUT_LOCATION}/${OUTPUTFILENAME}."  

           cp ${OUTPUTFILE} ${AFP_INPUT_LOCATION}/${OUTPUTFILENAME} 
        fi
     else 
        #Skipping as the outfile is an error file
        f_logInfo "Skipping copy of ${OUTPUTFILE}."
     fi

     f_logInfo "Processed ${AFP_FILE_COUNT} AFP files into input folder"  
  done
fi

###############################################################################
#Process any AFP files from output folder into gateway
###############################################################################
if [ $RUN_AFP = "YES" ] ; then

  f_logInfo "Copying AFP files, if any, from output folder to gateway nfs share.." 
  #Get list of output files - reset values for variables as may be running from interactive
  DOC1OUTPUTLOCATION=`echo ${LATESTLETTEROUTPUTLOCATION} | sed -e 's/letterProducerOutput/doc1ProducerOutput/g'`/
  OUTPUTFILELIST=`find ${DOC1OUTPUTLOCATION} -type f ! -size 0`

  #Reset AFP File count as we are working out number being processed
  AFP_FILE_COUNT=0;
   
  if [ $IGNORE_AFP_COUNT = "NO" ] ; then
     f_logInfo "Counting number of AFP files to process ..."
     #Iterate through counting number of AFP files
     for OUTPUTFILE in ${OUTPUTFILELIST}
     do
        OUTPUTFILENAME=${OUTPUTFILE##*/}
        for AFPFILE in ${AFP_FILES}
        do
           if [ ${OUTPUTFILENAME} = ${AFPFILE} ]; then
              #Filename in doc1 output is AFP file, therefore increament count
              f_logInfo "${OUTPUTFILENAME} matches AFP file - adding to AFP_FILE_COUNT" 
              ((AFP_FILE_COUNT=AFP_FILE_COUNT + 1))
           fi
        done
     done
     f_logInfo "Expected number of AFP files to process is ${AFP_FILE_COUNT}"
  else 
     f_logInfo "Ignoring count of AFP Files "
  fi

  #Check if any AFP Files - if so, monitor output folder
  if [ $AFP_FILE_COUNT -gt 0 ] || [ $IGNORE_AFP_COUNT = "YES" ] ; then
  
     AFP_OUT_FOLDER_COUNT=0;
     AFP_CHECK_COUNT=0;
     SLEEP_SECS=120;

     while [ $AFP_OUT_FOLDER_COUNT -lt $AFP_FILE_COUNT ] && [ $AFP_CHECK_COUNT -lt 10 ] 
     do
        f_logInfo "AFP File Count is $AFP_OUT_FOLDER_COUNT and expecting $AFP_FILE_COUNT ... sleeping for ${SLEEP_SECS} seconds"
        #Sleep while waiting for doc1
        sleep ${SLEEP_SECS}

        #Increment count of attempts 
        ((AFP_CHECK_COUNT=AFP_CHECK_COUNT + 1))

        AFP_OUT_FOLDER_COUNT=`ls -1 ${AFP_OUTPUT_LOCATION} | wc -l`
     done
     
     #If check count is > 10 AND we have a file discrepancy of not 1 - then alert as files have not been produced
     COUNT_DIFF=$(( $AFP_FILE_COUNT - $AFP_OUT_FOLDER_COUNT )) 
     f_logInfo "AFP_FILE_COUNT - AFP_OUT_FOLDER_COUNT = ${COUNT_DIFF}"

     if [ $AFP_CHECK_COUNT -ge 10 ] && [ $COUNT_DIFF -ne 1 ]; then
        f_logError "Incorrect number or no AFP files in AFP Output folder. Are processes running on DOC1 AFP server? Please investigate."
        patrol_log_alert_chaps_f " `pwd`/`basename $0`: Incorrect number or no AFP files in AFP Output folder. Are processes running on DOC1 AFP server? Please investigate."
        email_CHAPS_group_f "Incorrect number or no AFP files in AFP Output folder" "Incorrect number or no AFP files in AFP Output folder. Are processes running on DOC1 AFP server? Please investigate."
        exit 1
     else

        if (( $COUNT_DIFF == 1 ));then
           email_CHAPS_group_f "One incorrect number in AFP Output folder. CONTINUE BUT FIX" "One incorrect number in AFP Output folder. We will continue BUT we must fix and resend broken Letters. Please investigate."
           f_logError "One incorrect number in AFP Output folder. CONTINUE BUT FIX"
        fi 

        #Set variable for DOC1 gateway Location
        DOC1_GATEWAY_LOCATION=${DOC1_GATEWAY_LOCATION_EW}

        f_logInfo "Copying AFP output files to gateway nfs share.." 
        f_logInfo "Getting list of all output files in ${AFP_OUTPUT_LOCATION}"


        OUTPUTFILELIST=`find ${AFP_OUTPUT_LOCATION}/ -type f`

        for OUTPUTFILE in ${OUTPUTFILELIST}
        do
          f_logInfo "Output file found: ${OUTPUTFILE}"
           OUTPUTFILENAME=${OUTPUTFILE##*/}

           #Files in folder as expected so copy to gateway
           #SMC HSOL1 must be duplicated as a HS1COPY file before copying to the gateway
           if [[ ${OUTPUTFILENAME} = *"HSOL1."* ]]; then
              f_logInfo "Creating HS1COPY file from HSOL1 file"
              COPYFILE=`echo ${OUTPUTFILENAME} | sed 's/HSOL1/HS1COPY/g'`
              f_logInfo "COPYFILE is $COPYFILE"
              f_logInfo "Writing ${DOC1_GATEWAY_LOCATION}/${COPYFILE}"
              cp ${OUTPUTFILE} ${DOC1_GATEWAY_LOCATION}/${COPYFILE}
           fi

           #SL  HSOL1W must be duplicated as HS1CPYW file before copying to the gateway
           if [[ ${OUTPUTFILENAME} = *"HSOL1W."* ]]; then
              f_logInfo "Creating HS1CPYW file from HSOL1W file"
              COPYFILE=`echo ${OUTPUTFILENAME} | sed 's/HSOL1W/HS1CPYW/g'`
              f_logInfo "COPYFILE is $COPYFILE"
              f_logInfo "Writing ${DOC1_GATEWAY_LOCATION}/${COPYFILE}"
              cp ${OUTPUTFILE} ${DOC1_GATEWAY_LOCATION}/${COPYFILE}
           fi

           f_logInfo "Writing ${DOC1_GATEWAY_LOCATION}/${OUTPUTFILENAME}."

           mv ${OUTPUTFILE} ${DOC1_GATEWAY_LOCATION}/${OUTPUTFILENAME}
        done
     fi 
  fi
fi

f_logInfo "Finished Compliance Process." 
f_logInfo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
