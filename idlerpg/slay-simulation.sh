#!/bin/bash

# Author: Andrew Howard

ROLLS=10000
MEDUSAWINS=0
MEDUSALOSS=0
CENTAURWINS=0
CENTAURLOSS=0
MAMMOTHWINS=0
MAMMOTHLOSS=0
VAMPIREWINS=0
VAMPIRELOSS=0
DRAGONWINS=0
DRAGONLOSS=0
SPHINXWINS=0
SPHINXLOSS=0
HIPPOWINS=0
HIPPOLOSS=0

for x in `seq 1 $ROLLS`; do
  MYSUM=$1
  MYROLL=$(( $RANDOM % $MYSUM ))

  # Name	: Sum Range	: Sum Avg	: Min Gold
  # Medusa	: 1000 - 5000	: 3000		: 200
  # Centaur	: 1000 - 6000	: 3500		: 300
  # Mammoth	: 1000 - 7000	: 4000		: 400
  # Vampire	: 1000 - 8000	: 4500		: 500
  # Dragon	: 1000 - 9000	: 5000		: 700
  # Sphinx	: 1000 - 10000	: 5500		: 800
  # Hippogriff	: 1000 - 11000	: 6000		: 900

  MEDUSASUM=$(( ( $RANDOM % 4000 ) + 1000 ))
  MEDUSAROLL=$(( $RANDOM % $MEDUSASUM ))

  CENTAURSUM=$(( ( $RANDOM % 5000 ) + 1000 ))
  CENTAURROLL=$(( $RANDOM % $CENTAURSUM ))

  MAMMOTHSUM=$(( ( $RANDOM % 6000 ) + 1000 ))
  MAMMOTHROLL=$(( $RANDOM % $MAMMOTHSUM ))

  VAMPIRESUM=$(( ( $RANDOM % 7000 ) + 1000 ))
  VAMPIREROLL=$(( $RANDOM % $VAMPIRESUM ))

  DRAGONSUM=$(( ( $RANDOM % 8000 ) + 1000 ))
  DRAGONROLL=$(( $RANDOM % $DRAGONSUM ))

  SPHINXSUM=$(( ( $RANDOM % 9000 ) + 1000 ))
  SPHINXROLL=$(( $RANDOM % $SPHINXSUM ))

  HIPPOSUM=$(( ( $RANDOM % 10000 ) + 1000 ))
  HIPPOROLL=$(( $RANDOM % $HIPPOSUM ))

  if [ $MYROLL -lt $MEDUSAROLL ]; then 
    MEDUSAWINS=$(( $MEDUSAWINS+1 ))
  fi
  if [ $MYROLL -lt $CENTAURROLL ]; then 
    CENTAURWINS=$(( $CENTAURWINS+1 ))
  fi
  if [ $MYROLL -lt $MAMMOTHROLL ]; then 
    MAMMOTHWINS=$(( $MAMMOTHWINS+1 ))
  fi
  if [ $MYROLL -lt $VAMPIREROLL ]; then 
    VAMPIREWINS=$(( $VAMPIREWINS+1 ))
  fi
  if [ $MYROLL -lt $DRAGONROLL ]; then 
    DRAGONWINS=$(( $DRAGONWINS+1 ))
  fi
  if [ $MYROLL -lt $SPHINXROLL ]; then 
    SPHINXWINS=$(( $SPHINXWINS+1 ))
  fi
  if [ $MYROLL -lt $HIPPOROLL ]; then 
    HIPPOWINS=$(( $HIPPOWINS+1 ))
  fi
done

MEDUSAODDS=$( printf "%.3f" $(bc -l <<< "1 - $MEDUSAWINS / $ROLLS" ) )
CENTAURODDS=$( printf "%.3f" $(bc -l <<< "1 - $CENTAURWINS / $ROLLS" ) )
MAMMOTHODDS=$( printf "%.3f" $(bc -l <<< "1 - $MAMMOTHWINS / $ROLLS" ) )
VAMPIREODDS=$( printf "%.3f" $(bc -l <<< "1 - $VAMPIREWINS / $ROLLS" ) )
DRAGONODDS=$( printf "%.3f" $(bc -l <<< "1 - $DRAGONWINS / $ROLLS" ) )
SPHINXODDS=$( printf "%.3f" $(bc -l <<< "1 - $SPHINXWINS / $ROLLS" ) )
HIPPOODDS=$( printf "%.3f" $(bc -l <<< "1 - $HIPPOWINS / $ROLLS" ) )

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


