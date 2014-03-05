#!/bin/bash

source ~/idle-constants.sh
if [ $# -gt 0 ]; then
  PLAYERNAME=$1
fi

STATSPAGE=$( curl http://multirpg.net/xml.php?player=$PLAYERNAME 2>/dev/null )
PLAYERLEVEL=$( echo $STATSPAGE | \
  perl -pe 's/.*<level>(\d+)<\/level>.*/\1/' )
PLAYERSUM=$( echo $STATSPAGE | \
  perl -pe 's/.*<total>(\d+)<\/total>.*/\1/' )
LEVEL=$( echo $STATSPAGE | \
  perl -pe 's/.*<level>(\d+)<\/level>.*/\1/' )
ALIGNMENT=$( echo $STATSPAGE | \
  perl -pe 's/.*<alignment>(.)<\/alignment>.*/\1/' )
if [ $ALIGNMENT == "g" ]; then
 MULTIPLIER=1.1
elif [ $ALIGNMENT == "e" ]; then
  MULTIPLIER=0.9
else
  MULTIPLIER=1
fi
echo "Base sum: $PLAYERSUM"
echo "Player $PLAYERNAME has alignment modifier $MULTIPLIER" >&2
PLAYERSUM=$( printf "%.0f" $(bc -l <<< "$PLAYERSUM * $MULTIPLIER" ) )
echo "Modified sum: $PLAYERSUM"
HASHERO=$( echo $STATSPAGE | \
   perl -pe 's/.*<hero>(\d)<\/hero>.*/\1/' )
if [ $HASHERO -eq 1 ]; then
  HEROLEVEL=$( echo $STATSPAGE | \
    perl -pe 's/.*<herolevel>(\d)<\/herolevel>.*/\1/' )
  HEROBONUS=$( printf "%.2f" $(bc -l <<< "($HEROLEVEL + 2) / 100 + 1" ) )
  PLAYERSUM=$( printf "%.0f" $(bc -l <<< "$PLAYERSUM * $HEROBONUS") )
  echo "Player $PLAYERNAME has level $HEROLEVEL Hero - modifying sum by $HEROBONUS" >&2
fi
echo "Final sum: $PLAYERSUM"

HASENG=$( echo $STATSPAGE | \
   perl -pe 's/.*<engineer>(\d)<\/engineer>.*/\1/' )
if [ $HASENG -eq 1 ]; then
  ENGLEVEL=$( echo $STATSPAGE | \
    perl -pe 's/.*<englevel>(\d)<\/englevel>.*/\1/' )
  ENGBONUS=$( printf "%.2f" $(bc -l <<< "($ENGLEVEL + 2) / 100" ) )
else
  ENGBONUS=0
fi

(
echo "Mob Gold GoldLev Item ItemLev Total Delay MobC WinOdds Return"
cat monsters | tail -n +2 | while read LINE; do
  MOBNAME=`echo $LINE | awk '{print $1}'`
  MOBLEVEL=`echo $LINE | awk '{print $2}'`
  MOBSUM=`echo $LINE | awk '{print $3}'`
  MOBDELAY=`echo $LINE | awk '{print $4}' | cut -dx -f1`
  MOBGOLD=`echo $LINE | awk '{print $5}'`
  MOBITEM=`echo $LINE | awk '{print $6}'`

  GOLDLEV=$( printf "%.3f" $(bc -l <<< "$MOBGOLD / 20" ) )
  ITEMLEV=$( printf "%.3f" $(bc -l <<< "$MOBITEM * $ENGBONUS" ) | sed 's/\..*//')
  TOTALRETURN=$( printf "%.3f" $(bc -l <<< "$GOLDLEV + $ITEMLEV" ) )
  MOBCONSTANT=$( printf "%.3f" $(bc -l <<< "$TOTALRETURN / $MOBDELAY" ) )

  # Try to do it computationally
  if [ $MOBSUM -gt $PLAYERSUM ]; then
    # MOB has advantage.  Player will win 1/2 the times that the MOB rolls within Player's sum range.
    # Odds that monster rolls in the range that it's not a guaranteed loss
    FIGHTODDS=$( printf "%.3f" $(bc -l <<< "$PLAYERSUM / $MOBSUM" ) )
    # Odds that it monster rolls within Player's range, and Player rolls higher
    PERCENT=$( printf "%.3f" $(bc -l <<< "$FIGHTODDS / 2" ) )
  else
    # Player has advantage.  Calculate odds that monster wins and sub from 1.000
    # If player rolls higher than MOBSUM, player automatically wins.  They only fight if player rolls within MOB's range.
    FIGHTODDS=$( printf "%.3f" $(bc -l <<< "$MOBSUM / $PLAYERSUM" ) )
    # Assuming they roll within the same cap, it's 50/50.  MOB wins half of the cases where a fight occurs.
    # Since this is the only case where MOB wins, sub from 1.000 to find player's chance of winning.
    PERCENT=$( printf "%.3f" $(bc -l <<< "1 - $FIGHTODDS / 2" ) )
  fi

  RETURN=$( printf "%.3f" $(bc -l <<< "$PERCENT * $MOBCONSTANT" ) )

  if [ $PLAYERLEVEL -le $MOBLEVEL ]; then
    echo "$MOBNAME $MOBGOLD $GOLDLEV $MOBITEM $ITEMLEV $TOTALRETURN ${MOBDELAY}x $MOBCONSTANT $PERCENT $RETURN"
  fi
done 2>/dev/null | sort -nk 10
) | column -t

