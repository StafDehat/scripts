#!/bin/bash

# Author: Andrew Howard

# Pass number of minutes to sleep initially as an argument:
# ./idle-autoslay.sh 24
# Run in background and disown the process:
# ./idle-autoslay.sh 24 &
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
  # Determine what to attack
  if [ $LEVEL -lt 40 ]; then
    echo "Must be level 40 to slay.  You are level $LEVEL."
    echo "Waiting."
    sleep $(( 60 * 60 ))
    continue
  fi

  # Simulations have proven it's best to always attack the Hippogriff
  MONSTER=Hippogriff

  command "slay $MONSTER"

  sleep $(( 24 * 60 * 60 ))

done

