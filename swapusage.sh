#!/bin/bash

( echo "PID Mem(kB) Binary"
for x in `ls /proc/ | grep -e '^[0-9][0-9]*$'`; do
  PID=$x
  SWAP=`grep VmSwap /proc/$x/status | awk '{print $2}'`
  PROC=`ps aux | awk '$2 ~ /^'$PID'$/ {print $11}'`
  if [ ! -z "$SWAP" ]; then
    echo "$PID $SWAP $PROC"
  fi
done 2>/dev/null | sort -nk 2) | column -t

