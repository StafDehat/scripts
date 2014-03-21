#!/bin/bash
 
# Author: Andrew Howard

PARENTPIDS=`comm -12 <(ps -C httpd -C apache2 -o ppid | sort -u) <(ps -C httpd -C apache2 -o pid | sort -u)`
 
for ParPID in $PARENTPIDS; do
  SUM=0
  COUNT=0
  for x in `ps f --ppid $ParPID -o rss | tail -n +2`; do
    SUM=$(( $SUM + $x ))
    COUNT=$(( $COUNT + 1 ))
  done
 
  MEMPP=$(( $SUM / $COUNT / 1024 ))
  FREERAM=$(( `free | tail -2 | head -1 | awk '{print $4}'` / 1024 ))
  APACHERAM=$(( $SUM / 1024 ))
  APACHEMAX=$(( $APACHERAM + $FREERAM ))
 
  (
  echo
  echo "Info for the following parent apache process:"
  echo "  "`ps f --pid $ParPID -o command | tail -n +2`
  echo
  echo "Current # of apache processes:        $COUNT"
  echo "Average memory per apache process:    $MEMPP MB"
  echo "Free RAM (including cache & buffers): $FREERAM MB"
  echo "RAM currently in use by apache:       $APACHERAM MB"
  echo "Max RAM available to apache:          $APACHEMAX MB"
  echo 
  echo "Theoretical maximum MaxClients:  $(( $APACHEMAX / $MEMPP ))"
  echo "Recommended MaxClients:          $(( $APACHEMAX / 10 * 9 / $MEMPP ))"
  echo
  )
done
