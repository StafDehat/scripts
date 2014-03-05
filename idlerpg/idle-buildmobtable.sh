#!/bin/bash

source ~/average.sh

MOBS=`tail -n +2 ~/monsters | awk '{print $1}'`

(
echo "Name      Level Sum     Delay   AvgGold         AvgItem"
for x in $MOBS; do
  MOBNAME=$x
  MOBLEVEL=`egrep "^$MOBNAME\s" ~/monsters | awk '{print $2}'`
  MOBSUM=`egrep "^$MOBNAME\s" ~/monsters | awk '{print $3}'`
  MOBDELAY=`egrep "^$MOBNAME\s" ~/monsters | awk '{print $4}' | sed 's/x//'`
  MOBGOLD=`grep gold mob-$x | perl -pe 's/.*?(\d+) gold.*$/\1/' | average`
  MOBITEM=`grep level mob-$x | perl -pe 's/.*?level (\d+).*$/\1/' | average`
  echo "$MOBNAME $MOBLEVEL $MOBSUM ${MOBDELAY}x $MOBGOLD $MOBITEM"
done
) | column -t
