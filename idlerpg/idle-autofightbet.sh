#!/bin/bash

# Author: Andrew Howard

source ~/idle-constants.sh

LOCK_FILE=/tmp/`basename $0`.lock
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
  echo "Lock File exists - exiting"
  exit 1
fi
function cleanup {
  echo "Caught exit signal - deleting trap file"
  rm -f $LOCK_FILE
  rm -f $SCREENLOCK
  exit 2
}
trap 'cleanup' 1 2 9 15 17 19 23 EXIT


STATSPAGE=$( curl http://multirpg.net/xml.php?player=$PLAYERNAME 2>/dev/null )

LEVEL=$( echo $STATSPAGE | \
  perl -pe 's/^.*<level>(\d+)<\/level>.*$/\1/' )
FIGHTS=$( echo $STATSPAGE | \
  perl -pe 's/^.*<ffight>(\d)<\/ffight>.*$/\1/' )
BETS=$( echo $STATSPAGE | \
  perl -pe 's/^.*<bet>(\d)<\/bet>.*$/\1/' )
GOLD=$( echo $STATSPAGE | \
  perl -pe 's/^.*<gold>(\d+)<\/gold>.*$/\1/' )

# idle-fight-analyzer.sh is an expensive operation.
# Determine whether or not we even need to run it.
if [[ ( $LEVEL -ge 10 && $FIGHTS -lt 5 ) || \
      ( $LEVEL -ge 30 && $BETS -lt 5 && $GOLD -ge 100 ) ]]; then
  echo "Fights and/or bets remaining.  Proceeding."
else
  echo "No fights/bets remaining, or insufficient level, or insufficient gold.  Exiting."
  echo "Current level:     $LEVEL"
  echo
  echo "Need level 10+ to fight."
  echo "Fights used today: $FIGHTS / 5"
  echo
  echo "Need level 30+ to bet."
  echo "Bets used today:   $BETS / 5"
  echo "Need 100 gold per bet."
  echo "Gold:              $GOLD"
  exit
fi


# Attempt to grab a lock on the screen session
(set -C; : > $SCREENLOCK) 2> /dev/null
while [ $? != "0" ]; do
  echo "Lock File exists - waiting"
  sleep 60
  (set -C; : > $SCREENLOCK) 2> /dev/null
done

# Fight
# /msg multirpg fight <player>
if [[ $LEVEL -ge 10 && $FIGHTS -lt 5 ]]; then
  echo "Determining who to fight with...  (Could take a bit)"
  FIGHTODDS=$( ~/idle-fight-analyzer.sh $PLAYERNAME 2>/dev/null )
  TARGET=$( echo "$FIGHTODDS" | \
    grep -A 1 "You should challenge" | \
    tail -1 | \
    cut -d\' -f2 )
  CHANCE=$( echo "$FIGHTODDS" | \
    grep -A 1 "You should challenge" | \
    tail -1 | \
    awk '{print $4}' )
  if [ $(bc <<< "$CHANCE > 1.5") == 1 ]; then
    echo "Attacking $TARGET with $CHANCE odds of success."
    for x in `seq $FIGHTS 4`; do
      wall "Fighting another player on #multirpg in 10 seconds"
      sleep 10
      echo FIGHT
      screen -S $SCREENNAME -X stuff "/msg multirpg fight $TARGET"
      screen -S $SCREENNAME -X stuff $'\012'
    done
  else
    echo "Only have $CHANCE ratio of success - 1.2 required."
    echo "Unacceptable risk - not fighting."
  fi
fi

# Bet
# /msg multirpg bet <player to win> <player to lose> <gold to bet>
if [[ $LEVEL -ge 30 && $BETS -lt 5 && $GOLD -ge 100 ]]; then
  BETODDS=$( ~/idle-bet-analyzer.sh 2>/dev/null )
  if [ $? -ne 0 ]; then
    echo "ERROR: Can not determine odds.  Probably insufficient contestants."
    exit 1
  fi
  WINNER=$( echo "$BETODDS" | \
    grep -A 1 "You should bet on" | \
    tail -1 | \
    cut -d\' -f2 )
  LOSER=$( echo "$BETODDS" | \
    grep -A 1 "You should bet on" | \
    tail -1 | \
    cut -d\' -f4 )
  CHANCE=$( echo "$BETODDS" | \
    grep -A 1 "You should bet on" | \
    tail -1 | \
    awk '{print $6}' )

  if [ $(bc <<< "$CHANCE > 1.5") == 1 ]; then
    echo "Betting on $WINNER to beat $LOSER with $CHANCE odds of success."
    for x in `seq $BETS 4`; do
      if [ $GOLD -lt 100 ]; then
        echo "We may not have enough gold to continue.  Exiting"
        break
      fi
      wall "Placing a bet on #multirpg in 10 seconds"
      sleep 10
      echo BET
      GOLD=$(( $GOLD - 100 )) # Assume we lost for gold calculation purposes
      screen -S $SCREENNAME -X stuff "/msg multirpg bet $WINNER $LOSER 100"
      screen -S $SCREENNAME -X stuff $'\012'
    done
  else
    echo "Only have $CHANCE ratio of success - 1.5 required."
    echo "Unacceptable risk - not betting."
  fi
fi

# Release the screen session lock
rm -f $SCREENLOCK


