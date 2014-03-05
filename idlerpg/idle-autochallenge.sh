#!/bin/bash

# Pass number of minutes to sleep initially as an argument:
# ./idle-autochallenge.sh 24
# Run in background and disown the process:
# ./idle-autochallenge.sh 24 &
# jobs -l
# disown 12345

source ~/idle-constants.sh

if [ $# -gt 0 ]; then
  sleep $(( 60 * $1 ))
fi

while true; do
  STATSPAGE=$( curl http://multirpg.net/xml.php?player=$PLAYERNAME 2>/dev/null )

  LEVEL=$( echo $STATSPAGE | \
    perl -pe 's/.*<level>(\d+)<\/level>.*/\1/' )
  if [ $LEVEL -lt 35 ]; then
    echo "Must be level 35 to challenge.  You are level $LEVEL."
    echo "Waiting."
    sleep $(( 60 * 60 ))
    continue
  fi

  command "challenge"

  sleep $(( 3 * 60 * 60))
done

