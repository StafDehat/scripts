#!/bin/bash

# Author: Andrew Howard
# Holy shit, indirect references

# After creating logs of memcache stats with memcached-statuslog.sh, you can
#   use this script to print a report of how many operations occurred each
#   interval.
# Example usage:
#   ./memcached-deltas.sh cmd_get cmd_set curr_items

if [ $# -lt 1 ]; then
  echo "Gotta pass args"
  exit
fi

(
  for VAR in $@; do
    declare NOW_$VAR=0
  done
  echo "Time $@"
  for x in /var/log/memcached/*; do
    TIMESTAMP=$( basename $x )
    echo -n "$TIMESTAMP "

    for VAR in $@; do
      declare THEN_$VAR=$(eval "echo \$NOW_$VAR")
      declare NOW_$VAR="$( awk '$2 ~ /^'"$VAR"'$/ {print}' $x | sed 's/[^0-9]*\([0-9]*\).*/\1/' )"
      declare DIFF_$VAR=$(( $(eval "echo \$NOW_$VAR") - $(eval "echo \$THEN_$VAR") ))
      ECHO=$( eval "echo \$DIFF_$VAR" )
      echo -n "$ECHO "
    done

    echo
  done
) | column -t


