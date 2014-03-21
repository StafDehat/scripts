#!/bin/bash

# Author: Andrew Howard

# Pass number of minutes to sleep initially as an argument:
# ./idle-autoattack.sh 24
# Run in background and disown the process:
# ./idle-autoattack.sh 24 &
# jobs -l
# disown 12345

source ~/idle-constants.sh

if [ $# -gt 0 ]; then
  sleep $(( 60 * $1 ))
fi

while true; do
  STATSPAGE=$( curl http://multirpg.net/xml.php?player=$PLAYERNAME 2>/dev/null )

  PLAYERLEVEL=$( echo $STATSPAGE | \
    perl -pe 's/.*<level>(\d+)<\/level>.*/\1/' )
  # Determine what to attack
  if [ $PLAYERLEVEL -lt 10 ]; then
    echo "Must be level 10 to attack.  You are level $PLAYERLEVEL."
    echo "Waiting."
    sleep $(( 60 * 60 ))
    continue
  fi

  MOBSTATS=`~/attack-simulation.sh $PLAYERNAME 2>/dev/null`
  MONSTER=`echo "$MOBSTATS" | \
    tail -n 1 | \
    awk '{print $1}'`
  DELAY=`echo "$MOBSTATS" | \
    tail -n 1 | \
    awk '{print $7}' | \
    sed 's/x//'`

  command "attack $MONSTER"

  sleep $(( $PLAYERLEVEL * $DELAY * 60 ))

done

