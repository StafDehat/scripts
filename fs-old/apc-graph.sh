#!/bin/bash

function usage {
  echo "Usage: $0 [-l LOGFILE] [-s SCALE] [-t TRUNCATE] DEVICE"
  echo "  -l LOGFILE"
  echo "     Read raw data from LOGFILE"
  echo "     Default: /usr/local/nagios/var/nagios.log"
  echo "  -s SCALE"
  echo "     Each mark (X) represents SCALE units"
  echo "     Default: 5"
  echo "  -t TRUNCATE"
  echo "     Drop TRUNCATE marks (X) off each bar"
  echo "     Default: 0"
  exit
}

# Set defaults
LOGFILE=/usr/local/nagios/var/nagios.log
SCALE=5
TRUNCATE=1

# Handle command-line arguments
while getopts "hl:s:t:" FLAG
do
  case $FLAG in
    h  ) usage
         ;;
    l  ) LOGFILE=$OPTARG
         ;;
    s  ) SCALE=$OPTARG
         ;;
    t  ) TRUNCATE=$(( $OPTARG + 1 ))
         ;;
    *  ) echo "Unknown argument: $FLAG"
         usage
         ;;
  esac
done
shift $(( $OPTIND - 1 ))

# Ensure a device was specified, at the least
if [ $# -ne 1 ]; then
  usage
  exit 1
fi
# Verify existence of LOGFILE
if [ ! -e $LOGFILE ]; then
  echo "ERROR: Specified logfile does not exist"
  usage
fi
# Ensure SCALE is numeric
if [[ ! $SCALE =~ '^[0-9]+$' ]]; then
  echo "ERROR: Scale must be numeric"
  usage
fi
# Ensure TRUNCATE is numeric
if [[ ! $TRUNCATE =~ '^[0-9]+$' ]]; then
  echo "ERROR: Truncate value must be numeric"
  usage
fi

DEVICE=$1

LOGS=`grep "PROCESS_SERVICE_CHECK_RESULT;$DEVICE" $LOGFILE | \
        /root/scripts/unepoch.sh`

DATES=`echo "$LOGS" | cut -d: -f1 | sort -u`

echo "$DATES" | while read DATE; do
  SETX=`echo "$LOGS" | grep "$DATE" | awk '{print $NF}'`
  N=`echo "$SETX" | wc -l`
  SUMX=0
  for X in $SETX; do
    SUMX=$(( $SUMX + $X ))
  done
  AVG=$(( $SUMX / $N ))

  echo -ne "$DATE: ($AVG)\t"
  for X in `seq $TRUNCATE $(( $AVG / $SCALE ))`; do
    echo -n "X"
  done
  echo
done

