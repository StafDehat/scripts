#!/bin/bash

# Author: Andrew Howard

HOMEDIR=~
source ~/idle-constants.sh

# See if a PLAYERNAME was passed at command line
#if [ ]; then
#
#fi


STATSPAGE=$( curl http://multirpg.net/xml.php?player=$PLAYERNAME 2>/dev/null )
NEWLEVEL=$( echo $STATSPAGE | \
  perl -pe 's/.*<level>(\d+)<\/level>.*/\1/' )


# If file doesn't exist, determine current player level and exit
if [ ! -f $HOMEDIR/$PLAYERNAME.level ]; then
  echo $NEWLEVEL > $HOMEDIR/$PLAYERNAME.level
  echo "Old level not found - recorded new level and exit."
  exit 0
fi


# File must exist.  See if we've leveled recently.
OLDLEVEL=`cat $HOMEDIR/$PLAYERNAME.level`
if [ $NEWLEVEL -ne $OLDLEVEL ]; then
  # We've leveled.  Get a lock on the screen IO so nothing can happen for a bit.
  lock

  # Now check to see if anything has occurred since we leveled:
  savelog
  #This is matching too soon - we need the last occurrence of 'attained level'
  grep '<< PRIVMSG\|>> .*MegaHurts' tmp | sed -n '/attained level/,//p' tmp1 > tmp2

  
  # Kill the proc
  # Restart the proc
  $HOMEDIR/idle-autoattack.sh &
  disown $!

  $HOMEDIR/idle-autochallenge.sh &
  disown $!
  $HOMEDIR/idle-autoslay.sh &
  disown $!

  # Now things can resume normal writing to the screen.
  unlock
fi
