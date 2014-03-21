#!/bin/bash
 
# Author: Andrew Howard

DIRECTORY=/
getfacl --no-effective --recursive --skip-base --absolute-names $DIRECTORY | while read LINE; do
  if [ `echo "$LINE" | grep -ce '^# file'` -gt 0 ]; then
    FILE="`echo $LINE | cut -d\  -f3-`"
  elif [[ `echo "$LINE" | grep -ce '^#'` -gt 0 ||
          `echo "$LINE" | grep -ce '^\s*$'` -gt 0 ]]; then
    continue
  elif [ `echo "$LINE" | grep -c '::'` -eq 0 ]; then
    echo "setfacl -m $LINE $FILE"
  fi
done
