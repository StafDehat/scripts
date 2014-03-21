#!/bin/bash

# Author: Andrew Howard

# Pass number of minutes to sleep initially as an argument:
# ./idle-autoslay.sh 24
# Run in background and disown the process:
# ./idle-autoslay.sh 24 &
# jobs -l
# disown 12345

source ~/idle-constants.sh

#if [ $# -gt 0 ]; then
#  sleep $(( 60 * $1 ))
#fi


#while true; do
  STATSPAGE=$( curl http://multirpg.net/xml.php?player=$PLAYERNAME 2>/dev/null )
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
  #echo "Player $PLAYERNAME has alignment modifier $MULTIPLIER" >&2
  PLAYERSUM=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM * $MULTIPLIER" ) )
  HASHERO=$( echo $STATSPAGE | \
    perl -pe 's/.*<hero>(\d)<\/hero>.*/\1/' )
  if [ $HASHERO -eq 1 ]; then
    HEROLEVEL=$( echo $STATSPAGE | \
      perl -pe 's/.*<herolevel>(\d)<\/herolevel>.*/\1/' )
    HEROBONUS=$( printf "%.3f" $(bc -l <<< "($HEROLEVEL + 2) / 100 + 1" ) )
  #  echo "Player $PLAYERNAME has level $HEROLEVEL Hero - modifying sum by $HEROBONUS" >&2
    PLAYERSUM=$( printf "%.0f" $(bc -l <<< "$PLAYERSUM * $HEROBONUS") )
  fi

  # Name	: Sum Range	: Sum Avg	: Min Gold
  # Medusa	: 1000 - 5000	: 3000		: 200
  # Centaur	: 1000 - 6000	: 3500		: 300
  # Mammoth	: 1000 - 7000	: 4000		: 400
  # Vampire	: 1000 - 8000	: 4500		: 500
  # Dragon	: 1000 - 9000	: 5000		: 700
  # Sphinx	: 1000 - 10000	: 5500		: 800
  # Hippogriff	: 1000 - 11000	: 6000		: 900
  if [ $PLAYERSUM -le 3000 ]; then
    echo "Unlikely to succeed in slaying any monster."
    echo "Exiting."
    exit 1
  elif [ $PLAYERSUM -lt 7000 ]; then
    MONSTER=Medusa
  elif [ $PLAYERSUM -lt 8000 ]; then
    MONSTER=Centaur
  elif [ $PLAYERSUM -lt 9000 ]; then
    MONSTER=Mammoth
  elif [ $PLAYERSUM -lt 10000 ]; then
    MONSTER=Vampire
  elif [ $PLAYERSUM -lt 11000 ]; then
    MONSTER=Dragon
  elif [ $PLAYERSUM -lt 12000 ]; then
    MONSTER=Sphinx
  else
    MONSTER=Hippogriff
  fi

  MEDUSAODDS=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM / (3000 + $PLAYERSUM)" ) )
  CENTAURODDS=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM / (3500 + $PLAYERSUM)" ) )
  MAMMOTHODDS=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM / (4000 + $PLAYERSUM)" ) )
  VAMPIREODDS=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM / (4500 + $PLAYERSUM)" ) )
  DRAGONODDS=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM / (5000 + $PLAYERSUM)" ) )
  SPHINXODDS=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM / (5500 + $PLAYERSUM)" ) )
  HIPPOODDS=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM / (6000 + $PLAYERSUM)" ) )

  MEDUSARETURN=$( printf "%.3f" $(bc -l <<< "$MEDUSAODDS * 200" ) )
  CENTAURRETURN=$( printf "%.3f" $(bc -l <<< "$CENTAURODDS * 300" ) )
  MAMMOTHRETURN=$( printf "%.3f" $(bc -l <<< "$MAMMOTHODDS * 400" ) )
  VAMPIRERETURN=$( printf "%.3f" $(bc -l <<< "$VAMPIREODDS * 500" ) )
  DRAGONRETURN=$( printf "%.3f" $(bc -l <<< "$DRAGONODDS * 700" ) )
  SPHINXRETURN=$( printf "%.3f" $(bc -l <<< "$SPHINXODDS * 800" ) )
  HIPPORETURN=$( printf "%.3f" $(bc -l <<< "$HIPPOODDS * 900" ) )

  echo "My sum: $PLAYERSUM"

  (
    echo "Monster Odds Return"
    echo "Medusa $MEDUSAODDS $MEDUSARETURN"
    echo "Centaur $CENTAURODDS $CENTAURRETURN"
    echo "Mammoth $MAMMOTHODDS $MAMMOTHRETURN"
    echo "Vampire $VAMPIREODDS $VAMPIRERETURN"
    echo "Dragon $DRAGONODDS $DRAGONRETURN"
    echo "Sphinx $SPHINXODDS $SPHINXRETURN"
    echo "Hippogriff $HIPPOODDS $HIPPORETURN"
  ) | column -t

#  # Attempt to grab a lock on the screen session
#  (set -C; : > $SCREENLOCK) 2> /dev/null
#  while [ $? != "0" ]; do
#    echo "Lock File exists - waiting"
#    sleep 60
#    (set -C; : > $SCREENLOCK) 2> /dev/null
#  done
#  # Write to the screen
#  wall "Slaying $MONSTER on #multirpg in 10 seconds"
#  sleep 10
#  screen -S 23485.pts-0.dev -X stuff "/msg multirpg slay $MONSTER"
#  screen -S 23485.pts-0.dev -X stuff $'\012'
#  # Release the screen session lock
#  rm -f $SCREENLOCK

#  sleep $(( 24 * 60 * 60 ))

#done

