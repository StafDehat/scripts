#!/bin/bash

function usage {
  echo "Usage: $0 [SEED [SALT]]"
  echo "  SEED: Default is the date (YYYYMM)."
  echo "  SALT: Numeric, preferably 2-8 digits."
}

# Get the date, in YYYYMM form.
DATE=`date +%Y%m`

if [ $# -gt 0 ]; then
  DATE=$1
fi

# This will be 6 characters.  We calculate it because contants are bad form.
DATEC=$(( `echo $DATE | wc -c` - 1 ))

# Invert the digits of $DATE and store in $INVDATE.  Exmp: 200904 -> 409002
INVDATE=""
TEMP=$DATE
for x in `seq 1 $DATEC`; do
  INVDATE="$INVDATE$(( $TEMP % 10 ))"
  TEMP=$(( $TEMP / 10 ))
done

# Do some math to further randomize things
DIFF=`echo "$DATE - $INVDATE" | bc`
DIFF=${DIFF/-/}
PROD=`echo "$DATE * $INVDATE" | bc`
SUM=`echo "$DIFF + $PROD" | bc`
#echo "SUM = $SUM ($DIFF + $PROD)"

PASS=""
# 5525 = 2^2+1 * 2^4+1 * 2^6+1
# x * 5525 = ((((((x<<2) +x) <<4) +x) <<6) +x)
VAL=$(( $SUM * 5525 ))
while true; do
  # Grab a number, 0-93, from $VAL
  XY=$(( $VAL % 94 ))
  # Drop the least-significant digit from $VAL
  VAL=$(( $VAL / 10 ))
  # Pad $XY 33 numbers higher, to get into the printable character range of ASCII
  XY=$(( $XY + 33 ))
  # Convert $XY to base-8
  XY=`echo "obase=8;$XY" | bc`
  # Convert $XY to an ascii character
  XY=$(printf `echo '\'$XY`)
  # Append $XY to $PASS
  PASS="$PASS$XY"

  if [ $VAL -eq 0 ]; then
    break
  fi
done

echo "$DATE : $PASS"
