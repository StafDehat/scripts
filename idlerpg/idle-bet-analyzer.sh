#!/bin/bash

# Author: Andrew Howard

source ~/idle-constants.sh

weakestOpponent() {
  CHALLENGER=$1
  CHALLENGERLEVEL=$(echo "$ONLINEPLAYERS" | awk -F ? '{if ($2 == "'$CHALLENGER'") {print $3}}')
  CHALLENGERSUM=$(echo "$ONLINEPLAYERS" | awk -F ? '{if ($2 == "'$CHALLENGER'") {print $7}}')
  WEAKEST=$(echo "$ONLINEPLAYERS" | \
    grep -v ?$CHALLENGER? | \
    awk -F \? '$3 >= '$CHALLENGERLEVEL' {print $2"?"$7}' | \
    sort -t ? -nrk 2 | \
    tail -1)
  if [ ! -z "$WEAKEST" ]; then
    WEAKESTOPPONENT=$(echo $WEAKEST | cut -d? -f1)
    WEAKESTSUM=$(echo $WEAKEST | cut -d? -f2)
    printf "$CHALLENGER?$WEAKESTOPPONENT?%.3f\n" $(bc -l <<< "$CHALLENGERSUM / $WEAKESTSUM")
  fi
}

# Pull the list of online players from the site
echo "Pulling player list..." >&2
ONLINEPLAYERS=$( curl http://multirpg.net/players.php 2>/dev/null | \
  sed -n '/table/,/\/table/p' | \
  perl -pe 's/<(?!\/tr)(?!td)(?!\/td).*?>//g' | \
  sed '/^\s*$/d' | \
  sed 's/^\s*//' | \
  sed 's/></>-</g' | \
  perl -pe 's/<(?!\/tr).*?>//g' | \
  tr '\n' '?' | \
  sed 's/<\/tr>/\n/g' | \
  sed 's/^\?//' | \
  sed 's/?\s*$//' | \
  tail -n +2 | \
  sort -t ? -nk 1 | \
  grep ?YES? )

#
# Who to bet on
CONTESTANTS=`echo "$ONLINEPLAYERS" | awk -F ? '$3 >= 30 {print $2}' | wc -l`
if [ $CONTESTANTS -lt 2 ]; then
  echo "ERROR: No contestants"
  exit 1
fi
echo "Evaluating every player's weakest opponent..." >&2
WAGER=$(
#echo "$ONLINEPLAYERS" | grep -v "?$PLAYERNAME?" | awk -F ? '$3 >= 30 {print $2}' | while read PLAYER; do
echo "$ONLINEPLAYERS" | awk -F ? '$3 >= 30 {print $2}' | while read PLAYER; do
  weakestOpponent $PLAYER
done | sort -t ? -nk 3 | tail -1 )
VICTOR=$(echo $WAGER | cut -d? -f1)
LOSER=$(echo $WAGER | cut -d? -f2)
ODDS=$(echo $WAGER | cut -d? -f3)
echo
echo "You should bet on:"
echo "  '$VICTOR' to beat '$LOSER' with $ODDS to 1 odds"
echo
exit 0

