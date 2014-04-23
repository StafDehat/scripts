#!/bin/bash
# Author: Andrew Howard
# Apache only loads shared objects once, but every child process will 
# report memory as if it loaded the object itself. This means every process 
# is going to over-report its resident memory usage. This means you could 
# have a 4GB system that appears to have 6GB RAM in-use by apache. There's 
# no known way to get a precise value of actual RAM used by an apache 
# process (if you know one, please lodge a git issue).
# However, since the error is on both sides of the division, it cancels out. 
# This means the error only comes into effect in calculating how many 
# processes will use up the remaining, unused RAM, which means we'll err on 
# the side of caution by setting the value too low.  The estimate gets more 
# accurate as apache claims more RAM.
# Also note, the script has been updated to support multiple apache 
# instances on a single server. Each instance calculates its own MaxClients 
# value completely unaware of the other instance configurations, save for 
# the memory currently in use by those instances. If they were aware of each 
# other, I'd have to give MaxClients recommendations as a function of the 
# other, and it wouldn't make sense to any techs using the script.  This 
# almost never actually comes into effect.  In 99% of cases, there's only 
# one apache instance.

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
