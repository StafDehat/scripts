#!/bin/bash

while read LINE; do
  for ALLOCATION in $LINE; do
    CIDR=`echo $ALLOCATION | sed s/^.*"\/"//`
    NUMIPS=`echo "2^(32-$CIDR)-3" | bc`
    BASE=`echo $ALLOCATION | sed s/^".*\..*\..*\."// | sed s/"\/"$CIDR//`
    EXTC=`echo $ALLOCATION | sed s/$BASE"\/"$CIDR//`
    GATEWAY=$EXTC$(($BASE+1))
    NETMASK=255.255.255.$((253-$NUMIPS))

    echo "no ip address $GATEWAY $NETMASK secondary"
  done
done

