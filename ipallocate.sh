#!/bin/bash

function ATON {
  IPNUM=$1

  AMASK=16777216
  BMASK=65536
  CMASK=256

  AQUAD=$(( $IPNUM / $AMASK ))
  BQUAD=$(( $(( $IPNUM % AMASK )) / $BMASK ))
  CQUAD=$(( $(( $IPNUM % BMASK )) / $CMASK ))
  DQUAD=$(( $IPNUM % $CMASK ))

  IPADDR=$AQUAD.$BQUAD.$CQUAD.$DQUAD

  echo $IPADDR
}




if [[ -z $1 ]]; then
  DESIRED=8
else
  DESIRED=$1
fi

rm -f /tmp/ipallocate-gaps
rm -f /tmp/ipallocate-allocations
touch /tmp/ipallocate-gaps
touch /tmp/ipallocate-allocations

INPUT="1076232192/29 1076232200/30 1076232220/30 1076232224/29 1076232264/29 1076232296/29 1076232320/25"

echo "Existing allocations:"
for x in $INPUT; do
  IPNUM=`echo $x | cut -d/ -f1`
  CIDR=`echo $x | cut -d/ -f2`
  echo "`ATON $IPNUM`/$CIDR"
done

CIDR=$(( 32 - `echo "l($DESIRED)/l(2)" | bc -l | cut -d. -f1` ))
echo "Searching for $DESIRED free IPs ($CIDR)"

x=0
for IP in $INPUT; do
  ips[$x]=$IP
  x=$(( x + 1 ))
done
for COUNT in `seq 0 $(( ${#ips[*]} - 1 ))`; do
  IP=${ips[$COUNT]}
  FIRST=`echo $IP | cut -d/ -f1`
  CIDR=`echo $IP | cut -d/ -f2`
  SIZE=`echo "2 ^ ( 32 - $CIDR )" | bc`

  NEWBASE=$(( $FIRST + $SIZE ))
  LAST=$(( $NEWBASE - 1 ))

  if [[ $COUNT -lt $(( ${#ips[*]} - 1 )) ]]; then
    NEXTIP=${ips[$(( $COUNT + 1 ))]}
    NEXTNUM=`echo $NEXTIP | cut -d/ -f1`
  else
    NEXTNUM=1076232448 #Parent allocation base + size of parent
  fi

  echo "`ATON $FIRST | cut -d. -f4`-`ATON $LAST | cut -d. -f4`" >> /tmp/ipallocate-allocations
#  echo "Next allocation would be at `ATON $NEWBASE`"
#  echo `ATON $NEXTNUM` is the limit

  #
  # Shift forward as necessary to align potential new location with legal bit boundaries
  if [[ $(( $NEWBASE % $DESIRED )) -ne 0 ]]; then
    NEWBASE=$(( $NEWBASE + $(( $NEWBASE % $DESIRED )) ))
  fi

  #
  # Calculate the size of this hole
  GAPSIZE=$(( $NEXTNUM - $NEWBASE ))

  #
  # If gap is sufficiently large, report that this hole is a possibility
  if [[ $GAPSIZE -ge $DESIRED ]]; then
    echo "$GAPSIZE:`ATON $NEWBASE`" >> /tmp/ipallocate-gaps
  fi

  #
  # Sort the possibilities by gap size.  Create allocate in the smallest gap.
done

if [[ `cat /tmp/ipallocate-gaps | wc -l` -lt 1 ]]; then
  echo "Sorry, no gaps big enough for that allocation."
else
  NEWBASE=`sort -n /tmp/ipallocate-gaps | head -1 | cut -d: -f2`
  DQUAD=`echo $NEWBASE | cut -d. -f4`
  echo "$DQUAD-$(( $DQUAD + $DESIRED - 1 ))" >> /tmp/ipallocate-allocations
  CIDR=$(( 32 - `echo "l(8)/l(2)" | bc -l | cut -d. -f1` ))
  echo "New allocation: $NEWBASE/$CIDR"
fi

read -p "Draw a pretty picture? [y/N]: " OPT
if [[ $OPT == "y" || $OPT == "Y" ]]; then
  #
  # Draw a picture, for no good reason
  for x in `seq 0 255`; do
    PRINTED=0
    echo -en "$x:\t"
    for y in `cat /tmp/ipallocate-allocations`; do
      START=`echo $y | cut -d\- -f1`
      FINISH=`echo $y | cut -d\- -f2`
      if [[ $x -eq $START ]]; then
        echo "vvvvv"
        PRINTED=1
      elif [[ $x -eq $FINISH ]]; then
        echo "^^^^^"
        PRINTED=1
      elif [[ $x -gt $START && $x -lt $FINISH ]]; then
        echo "xxxxx"
        PRINTED=1
      fi
    done
    if [[ $PRINTED -eq 0 ]]; then
      echo ""
    fi
  done
fi

