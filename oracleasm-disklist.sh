#!/bin/bash

for DISKNAME in `/etc/init.d/oracleasm listdisks`; do
  DISKID=`oracleasm querydisk -d $DISKNAME | perl -pe 's/^.*\[(.*)\].*$/\1/'`
  ID1=`echo $DISKID | cut -d, -f1`
  ID2=`echo $DISKID | cut -d, -f2`
  DEVNAME=`ls -l /dev/* | awk '$5 ~ /^'$ID1',$/ && $6 ~ /^'$ID2'$/ {print $NF}'`
  echo $DISKNAME $DEVNAME
done | column -t

