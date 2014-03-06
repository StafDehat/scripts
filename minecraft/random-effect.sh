#!/bin/bash

PLAYERS=`/sbin/service minecraft command /list | tail -n +3 | cut -d\  -f4- | sed 's/,//g'`
EFFECT=`echo $(( $RANDOM % 19 + 1 ))`
DURATION=60
LEVEL=`echo $(( $RANDOM % 3 + 1 ))`

for PLAYER in $PLAYERS; do
  /sbin/service minecraft command "/effect $PLAYER $EFFECT $DURATION 1"
done

