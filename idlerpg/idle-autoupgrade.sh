#!/bin/bash

# Author: Andrew Howard

source ~/idle-constants.sh

STATSPAGE=$( curl http://multirpg.net/xml.php?player=$PLAYERNAME 2>/dev/null )

GOLD=$( echo $STATSPAGE | \
  perl -pe 's/^.*<gold>(\d+)<\/gold>.*$/\1/' )
LEVEL=$( echo $STATSPAGE | \
  perl -pe 's/^.*<level>(\d+)<\/level>.*$/\1/' )

# Buy an engineer if we don't already have one
HASENG=$( echo $STATSPAGE | \
   perl -pe 's/.*<engineer>(\d)<\/engineer>.*/\1/' )
if [ $HASENG  -eq 0 ]; then
  echo "Player does not yet have engineer.  Not upgrading."
  if [[ $GOLD -gt 1000 &&
        $LEVEL -gt 15 ]]; then
    command "hire engineer"
  fi
  exit 0
fi

# Upgrade engineer if it's not already maxed
ENGLEVEL=$( echo $STATSPAGE | \
  perl -pe 's/.*<englevel>(\d)<\/englevel>.*/\1/' )
if [ $ENGLEVEL -lt 9 ]; then
  echo "Player's engineer under level 9.  Not upgrading."
  if [ $GOLD -gt 400 ]; then
    command "engineer level"
  fi
  exit 0
fi

# Buy a hero if we don't already have one
HASHERO=$( echo $STATSPAGE | \
  perl -pe 's/.*<hero>(\d)<\/hero>.*/\1/' )
if [ $HASHERO -eq 0 ]; then
  echo "Player does not yet have hero.  Not upgrading."
  if [ $GOLD -gt 1000 ]; then
    command "summon hero"
  fi
  exit 0
fi

# Upgrade hero if it's not already maxed
HEROLEVEL=$( echo $STATSPAGE | \
  perl -pe 's/.*<herolevel>(\d)<\/herolevel>.*/\1/' )
if [ $HEROLEVEL -lt 9 ]; then
  echo "Player's hero under level 9.  Not upgrading."
  if [ $GOLD -gt 400 ]; then
    command "hero level"
  fi
  exit 0
fi

# Keep some gold in reserve
if [ $GOLD -le 400 ]; then
  echo "Insuficient gold to upgrade items - need 400, have $GOLD."
  echo "Exiting."
  exit 1
fi

ITEMS=$( echo "$STATSPAGE" | \
  sed -n '/items/,/\/items/p' | \
  tail -n +2 | \
  head -n -2 )
WEAKEST=$(
  echo "$ITEMS" | while read ITEM; do
    UNIT=$( echo $ITEM | \
      perl -pe 's/^\s*<(.*?)>.*$/\1/' )
    VALUE=$( echo $ITEM | \
      perl -pe 's/.*?(\d+).*$/\1/' )
    echo $VALUE $UNIT
  done | sort -n | head -n 1 | cut -d\  -f2 )
STRONGEST=$(
  echo "$ITEMS" | while read ITEM; do
    UNIT=$( echo $ITEM | \
      perl -pe 's/^\s*<(.*?)>.*$/\1/' )
    VALUE=$( echo $ITEM | \
      perl -pe 's/.*?(\d+).*$/\1/' )
    echo $VALUE $UNIT
  done | sort -n | tail -n 1 | cut -d\  -f2 )

command "upgrade $WEAKEST 10"

exit 0
