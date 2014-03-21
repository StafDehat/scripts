#!/bin/bash

# Author: Andrew Howard

#
# Usage statement
function usage {
  echo "Usage: $0 -l THE_LIST -n NUM_TECHS"
  echo "Distribute servers specified in THE_LIST reasonably equitably among NUM_TECHS techs."
  echo "Example: $0 -l /root/defcon-servers -n 18"
  echo ""
}

#
# Command-line arguments
LIST=""
NUMTECHS=0
while getopts ":hl:n:" arg
do
  case $arg in
    h  ) # Print help
         usage
         exit 1
         ;;
    l  ) # Set the file to use as the list of servers
         LIST=$OPTARG
         ;;
    n  ) # Set number of techs
         NUMTECHS=$OPTARG
         ;;
    *  ) # Default
         usage
         exit 1
         ;;
  esac
done
shift $(($OPTIND - 1))

#
# Sanity check
if [ -z $LIST ]; then
  echo "ERROR: You must specify a file containing the list of servers to assign"
  echo ""
  usage
  exit 1
elif [ ! -f $LIST ]; then
  echo "ERROR: The specified file ($LIST) does not exist"
  echo ""
  usage
  exit 1
elif [[ ! $NUMTECHS =~ '^[0-9]+$' ]]; then
  echo "ERROR: The number of techs must be numeric"
  echo ""
  usage
  exit 1
elif [[ $NUMTECHS -eq 0 ]]; then
  echo "ERROR: You must specify a number of techs with "-n X", where X is a whole number greater than 0"
  echo ""
  usage
  exit 1
fi

#
# Initialization
rm -f /tmp/defcon*
for x in `seq 0 $(( $NUMTECHS - 1 ))`; do
  assigned[$x]=0
  echo -n > /tmp/defcon$x
done

#
# Weights - To give Tech01 10 fewer servers than the average, set assigned[1]=10
# assigned[1]=10
# assigned[5]=5

#
# Return the index with the fewest assignments
function getFewest {
  for x in `seq 0 $(( $NUMTECHS - 1 ))`; do
    echo "$x ${assigned[$x]}"
  done \
  | sort -nk 2 | head -1 | cut -d\  -f1
}

#
# Assign servers CID-at-a-time to techs
cat $LIST | awk -F , '{print $2}' \
  | grep -vE '^u?21962$' \
  | grep -vE '^u?22508$' \
  | grep -vE '^u?22829$' \
  | uniq -c | sort -nr | while read LINE; do

  curTech=`getFewest`
  curCID=`echo $LINE | cut -d\  -f2`
  numServs=`echo $LINE | cut -d\  -f1`

  awk -F, '{if ($2=="'$curCID'") print $0}' $LIST >> /tmp/defcon$curTech
  assigned[$curTech]=$(( ${assigned[$curTech]} + $numServs ))
done


#
# Print some stats on what was assigned
TOTAL=`wc -l /tmp/defcon* | tail -1 | awk '{print $1}'`
MAX=`wc -l /tmp/defcon* | sort -nr | head -2 | tail -1 | awk '{print $1}'`
MIN=`wc -l /tmp/defcon* | sort -n | head -1 | awk '{print $1}'`
echo "Total servers:    $TOTAL"
echo "Max assigned:     $MAX"
echo "Average per tech: $(( $TOTAL / $NUMTECHS ))"
echo "Min assigned:     $MIN"
echo
echo
echo "Assignments:"
for x in  `seq 0 $(( $NUMTECHS - 1 ))`; do
  echo "TECH-NUM-$x- `cat /tmp/defcon$x | wc -l`"
done
echo
echo

#
# Print a list for each tech (Requires a tech-to-ID# file)
for x in `seq 0 $(( $NUMTECHS - 1 ))`; do
  TECH="TECH-NUM-$x-"

  echo $TECH
  (echo "ServerID,CID,QRR,Label"
   cat /tmp/defcon$x | cut -d, -f1,2,6,7- | sed 's/,N,/, ,/') \
  | column -t -s ,
  echo
  echo
done

