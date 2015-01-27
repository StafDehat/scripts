#!/bin/bash

# Author: Andrew Howard
# Note - this doesn't actually scrub users - just finds 'em.
# Someday it might delete/disable 'em too.

#
# Check for shell users that might be our guy
COUNT=$( grep -ci 'john\|doe' /etc/passwd )
echo "Matching lines in /etc/passwd: $COUNT"
if [ $COUNT -gt 0 ]; then
  grep -i 'john\|doe' /etc/passwd
fi

#
# Check for mysql users that might be our guy
COUNT=$( ps auxf | grep -ci my[s]ql )
if [ $COUNT -gt 0 ]; then
  which mysql &>/dev/null
  if [ $? -eq 0 ]; then
    COUNT=$( mysql mysql -te "select host,user from user;" | grep -ci 'john\|doe' )
    echo "Matching users in MySQL: $COUNT"
    if [ $COUNT -gt 0 ]; then
      mysql mysql -te "select host,user from user;" | grep -i 'john\|doe'
    fi
  else
    echo "MySQL seems to be running, but we couldn't find a client binary."
  fi
else
  echo "MySQL not running."
fi

echo "--------------------------------------------------"
echo


