#!/bin/bash

source ~/idle-constants.sh

STATSPAGE=$( curl http://multirpg.net/xml.php?player=$PLAYERNAME 2>/dev/null )
ONLINE=$( echo $STATSPAGE | \
  perl -pe 's/.*<online>(\d)<\/online>.*/\1/' )
if [ $ONLINE -eq 1 ]; then
  echo "Still logged in."
  exit 0
fi

command "login $PLAYERNAME $PASSWORD"
exit 0

