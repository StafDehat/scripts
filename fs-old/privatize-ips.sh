#!/bin/bash

while read LINE; do
  for ALLOCATION in $LINE; do
    CIDR=`echo $ALLOCATION | cut -d/ -f2`
    NUMIPS=`echo "2^(32-$CIDR)-3" | bc`
    BASE=`echo $ALLOCATION | cut -d/ -f1 | cut -d. -f4`
    EXTC=`echo $ALLOCATION | cut -d. -f1-3`.
    INTC=10.10.`echo $ALLOCATION | cut -d. -f3`.
    GATEWAY=$EXTC$(($BASE+1))
    NETMASK=255.255.255.$((253-$NUMIPS))

    for x in `seq 1 $NUMIPS`; do
      echo "netsh interface ip add address name=\"Public\" addr=$INTC$(($BASE+1+$x)) mask=255.255.0.0"
    done
  done
done

