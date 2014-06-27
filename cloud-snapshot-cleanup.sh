#!/bin/bash


HOURS=24
EXPIRE=$(( 60 * 60 * $HOURS ))
VHDS=$( xe vdi-list is-a-snapshot=true params=uuid | awk '{print $NF}' )
for VHD in $VHDS; do
  DATE=$( xe vdi-list uuid=$VHD params=snapshot-time | awk '{print $NF}' )
  DATE=$( date +%s -d "$( echo $DATE | sed 's/T/ /' )" )
  NOW=$( date +%s )
  AGE=$(( $NOW - $DATE ))
  if [ $AGE -gt $EXPIRE ]; then
    xe vdi-destroy uuid=$VHD
  fi
done
