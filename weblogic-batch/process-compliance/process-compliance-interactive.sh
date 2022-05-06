#!/bin/bash

# Runs an interactive menu which sets control variables to pass to process-compliance.sh

################################################################################
# Functions
################################################################################
Help() {
  clear && echo "Process Compliance Interactive help. "
  echo ""
  echo "This is an interactive menu for running the following jobs - along with process completion checks and file transfers."
  echo ""
  echo "ComplianceTrigger, LetterProducer, DOC1Producer, AFPProducer"
  echo ""
  echo "To run just enter ./$(basename $0) -r in working directory."
  echo "$USAGE"
  echo ""
  echo "It sets variables then runs ./process-compliance.sh which uses these variables to decide what runs or not."
  echo ""
  echo "This menu will prompt you with the following options:"
  echo "1) Run_From_Compliance - This will run the entire suite. Similar to standard operation."
  echo "2) Run_From_Letter - This will run LetterProducer, Doc1 and AFP, NOT compliance."
  echo "3) Run_From_Doc1 - This will run Doc1 and AFP NOT Compliance and LetterProducer."
  echo "4) Run_From_AFP - This will run AFP NOT Compliance, LetterProducer and Doc1."
  echo "5) Run_From_AFP (Ignore count) - Same as 4), but not performing check for number of expected AFP output files."
  echo ""
  echo "Select one and it will tell you what it does and prompt you to enter y/n."
  echo "Don't worry, it will prompt you again showing you what variables you set. "
  echo ""
  echo "Thats it, it runs in background and sends output to logs."
  echo ""
}

YesNo() {
    echo -e "$1 (y/n)? \c"
    read RESPONSE
    case "$RESPONSE" in
        [yY]|[Yy][Ee][Ss]) RESPONSE=y ;;
        *) RESPONSE=n ;;
    esac
}

PrintVar() {
  echo -e "\nRUN_COMPLIANCE=$RUN_COMPLIANCE"
  echo "RUN_LETTERPRODUCER=$RUN_LETTERPRODUCER"
  echo "RUN_DOC1=$RUN_DOC1"
  echo "RUN_AFP=$RUN_AFP"
}

################################################################################
#Set working directory and load environment variables
################################################################################
cd ${0%/*}

USAGE="Usage: $(basename $0) [-h|-help|-r|-repair]"
PS3="Make a selection => " ; export PS3
export INTERACTIVE="YES"
export RUN_COMPLIANCE="NO"
export RUN_LETTERPRODUCER="NO"
export RUN_DOC1="NO"
export RUN_AFP="NO"
export IGNORE_AFP_COUNT="NO"

###############################################################################
#Check if args are correct, this script is already running, or has failed previously
###############################################################################
if [ $# -ne 1 ] ; then
    echo "$USAGE"
    exit 1
fi

###############################################################################
# Set the control variables that decide what jobs should be run
# If user selects -repair, it drops into Interacitve Mode and prompts user for a responce. THIS CANNOT BE USED IN CRON.
###############################################################################
case "$1" in
    -h|-help)
        Help
        exit 0
        ;;
    -r|-repair)
        clear && echo -e "\nProcess Compliance Interactive menu. \n" && sleep 1
        
        select ACTION in Run_From_Compliance Run_From_Letter Run_From_Doc1 Run_From_AFP Run_From_AFP_No_Count EXIT
        do
          case $ACTION in
            Run_From_Compliance)
              YesNo "This will run the entire suite. Similar to standard operation. I'll ask you twice. Continue with this"
              if [ "$RESPONSE" = "y" ] ; then
                RUN_COMPLIANCE="YES"
                RUN_LETTERPRODUCER="YES"
                RUN_DOC1="YES"
                RUN_AFP="YES"
                break
              else
                echo Cancelling run and exiting script.
                exit 0		     
              fi
              ;;
            Run_From_Letter)
              YesNo "This will run LetterProducer, Doc1 and AFP, NOT compliance. I'll ask you twice. Continue with this"
              if [ "$RESPONSE" = "y" ] ; then
                RUN_COMPLIANCE="NO"
                RUN_LETTERPRODUCER="YES"
                RUN_DOC1="YES"
                RUN_AFP="YES"
                break
              else
                echo Cancelling run and exiting script.
                exit 0
              fi
              ;;
            Run_From_Doc1)
              YesNo "This will run Doc1 and AFP NOT Compliance and LetterProducer. I'll ask you twice. Continue with this"
              if [ "$RESPONSE" = "y" ] ; then
                RUN_COMPLIANCE="NO"
                RUN_LETTERPRODUCER="NO"
                RUN_DOC1="YES"
                RUN_AFP="YES"
                break
              else
                echo Cancelling run and exiting script.
                exit 0
              fi
              ;;
            Run_From_AFP)
              YesNo "This will run AFP NOT Doc1, Compliance and LetterProducer. I'll ask you twice. Continue with this"
              if [ "$RESPONSE" = "y" ] ; then
                RUN_COMPLIANCE="NO"
                RUN_LETTERPRODUCER="NO"
                RUN_DOC1="NO"
                RUN_AFP="YES"
                break
              else
                echo Cancelling run and exiting script.
                exit 0
              fi
              ;;
            Run_From_AFP_No_Count)
              YesNo "This will run AFP (Ignoring count) NOT Doc1, Compliance and LetterProducer. I'll ask you twice. Continue with this"
              if [ "$RESPONSE" = "y" ] ; then
                RUN_COMPLIANCE="NO"
                RUN_LETTERPRODUCER="NO"
                RUN_DOC1="NO"
                RUN_AFP="YES"
                IGNORE_AFP_COUNT="YES"
                break
              else
                echo Cancelling run and exiting script.
                exit 0
              fi
              ;;
            EXIT) 
              echo Cancelling run and exiting script.
              exit 0
              ;;
            *) echo "ERROR: Invalid selection."
              exit 1
              ;;
          esac
        done
        ;;
    *)
       echo "$USAGE" 
       exit 1
       ;;
esac

###############################################################################
# One last Interactive Mode check before we GO
###############################################################################

if [ $INTERACTIVE = "YES" ] ; then
  PrintVar
  YesNo "Above are the parameters. Last chance, are you ready to proceed"
  if [ "$RESPONSE" = "n" ] ; then
    echo Cancelling run and exiting script.
    exit 0
  fi
fi

###############################################################################
# BELOW HERE STARTS RUNTIME SCRIPTS 
###############################################################################

# Standard logging will be handled in main script.  Not used in this script to avoid clashes with interactive menu...
echo ""
echo `date`": Starting Compliance Process script. This will be sent to background. Check log under /apps/oracle/logs/process-compliance."  
nohup ./process-compliance.sh &
