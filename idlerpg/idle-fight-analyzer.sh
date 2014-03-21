#!/bin/bash

# Author: Andrew Howard

source ~/idle-constants.sh

if [ $# -ge 1 ]; then
  PLAYERNAME=$1
fi

weakestOpponent() {
  CHALLENGER=$1
  CHALLENGERLEVEL=$(echo "$ONLINEPLAYERS" | awk -F ? '{if ($2 == "'$CHALLENGER'") {print $3}}')
  CHALLENGERSUM=$(echo "$ONLINEPLAYERS" | awk -F ? '{if ($2 == "'$CHALLENGER'") {print $7}}')
  WEAKEST=$(echo "$ONLINEPLAYERS" | \
    grep -v ?$CHALLENGER? | \
    awk -F \? '$3 > '$CHALLENGERLEVEL' {print $2"?"$7}' | \
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

# Adjust their SUM based on alignment
echo "Adjusting player strength based on alignment and heroes... (could take a bit)" >&2
ONLINEPLAYERS=$(
  echo "$ONLINEPLAYERS" | while read PLAYERSTAT; do
    PLAYERNAME=$(echo "$PLAYERSTAT" | cut -d? -f2 )
    STATSPAGE=$( curl -g "http://multirpg.net/xml.php?player=$PLAYERNAME" 2>/dev/null )
    PLAYERSUM=$( echo $STATSPAGE | \
      perl -pe 's/.*<total>(\d+)<\/total>.*/\1/' )
    ALIGNMENT=$( echo $STATSPAGE | \
      perl -pe 's/.*<alignment>(.)<\/alignment>.*/\1/' )
    if [ $ALIGNMENT == "g" ]; then
      MULTIPLIER=1.1
    elif [ $ALIGNMENT == "e" ]; then
      MULTIPLIER=0.9
    else
      MULTIPLIER=1
    fi
    echo "Player $PLAYERNAME has alignment modifier $MULTIPLIER" >&2
    PLAYERSUM=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM * $MULTIPLIER" ) )
    HASHERO=$( echo $STATSPAGE | \
      perl -pe 's/.*<hero>(\d)<\/hero>.*/\1/' )
    if [ $HASHERO -eq 1 ]; then
      HEROLEVEL=$( echo $STATSPAGE | \
        perl -pe 's/.*<herolevel>(\d)<\/herolevel>.*/\1/' )
      HEROBONUS=$( printf "%.3f" $(bc -l <<< "($HEROLEVEL + 2) / 100 + 1" ) )
      PLAYERSUM=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM * $HEROBONUS") )
      echo "Player $PLAYERNAME has level $HEROLEVEL Hero - modifying sum by $HEROBONUS" >&2
    fi
    NEWLINE=$( echo $PLAYERSTAT | cut -d? -f1-6 | sed 's/\s*$//' )
    NEWLINE=$NEWLINE$(echo "?$PLAYERSUM?")
    NEWLINE=$NEWLINE$( echo $PLAYERSTAT | cut -d? -f8- )
    echo "$NEWLINE"
  done
)


#
# Who to fight
echo "Determining your best opponent..." >&2
WAGER=$(weakestOpponent $PLAYERNAME)
LOSER=$(echo $WAGER | cut -d? -f2)
ODDS=$(echo $WAGER | cut -d? -f3)
echo "You should challenge:"
echo "  '$LOSER' with a $ODDS to 1 chance of success"
echo
