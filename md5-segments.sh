#!/bin/bash

# Author: Andrew Howard
# Calculate md5sum of a file, 1G at a time

FILE="$1"
SIZE=$( stat -c %s "$FILE" )
MAXSIZE=1073741824 #1G
SEGMENTS=$(( $SIZE / $MAXSIZE ))
if [ $(( $SIZE % $MAXSIZE )) -eq 0 ]; then
  SEGMENTS=$(( $SEGMENTS - 1 ))
fi

echo "MD5 sum of $FILE"
echo "Total segments: $(( $SEGMENTS + 1 ))"
echo 
echo "Segment-Number : md5sum"
for COUNT in $( seq -w 0 $SEGMENTS ); do
  RSIZE=$(($MAXSIZE/4096))
  # bs=4096 -- Attempt to optimize read speeds by matching block size on drive architecture
  # count=$RSIZE -- Read $MAXSIZE bytes
  # skip=$RSIZE * $COUNT -- Skip previously-read $MAXSIZE chunks
  MD5=$( dd if="$FILE" bs=4k count=$RSIZE skip=$(( $RSIZE * $((10#$COUNT)) )) 2>/dev/null \
           | md5sum | awk '{print $1}' )
  echo "$COUNT : $MD5"
done

