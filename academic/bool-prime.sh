#!/bin/bash

# Author: Andrew Howard

if [ -z $1 ]; then
  echo "Usage: $0 MAX"
  echo "  MAX: Ceiling value under which to calculate primes"
  exit 1
elif [ `echo $1 | sed 's/^[0-9]*//' | wc -c` -ne 1 ]; then
  echo "ERROR: Argument MAX must be a number"
  echo "Usage: $0 MAX"
  echo "  MAX: Ceiling value under which to calculate primes"
  exit 1
else
  MAX=$1
fi

#
# Initialize all numbers to prime
for x in `seq 2 $MAX`; do
  primes[$x]=1;
done

#
# Mark as non-prime, any number that's a multiple of $x
for x in `seq 2 $( echo "sqrt($MAX)" | bc )`; do
  if [ ${primes[$x]} -eq 1 ]; then
    MULT=$(( $x + $x ))
    while [ $MULT -le $MAX ]; do
      primes[$MULT]=0
      MULT=$(( $MULT + $x ))
    done
  fi
done

exit

#
# Print the primes
for x in `seq 2 $MAX`; do
  if [ ${primes[$x]} -eq 1 ]; then
    echo $x
  fi
done

