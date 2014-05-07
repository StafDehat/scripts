#!/bin/bash
# Author: Andrew Howard

# This script sets these bash variables with the settings Holland will use:
# user
# password
# defaults-extra-file

# It's mostly useful as a demo for indirect references


MAINCONF=/etc/holland/holland.conf
BKUPSET=/etc/holland/backupsets/$( grep '^\s*backupsets' $MAINCONF | awk '{print $NF}' ).conf
PLUGIN=/etc/holland/providers/$( grep '^\s*plugin' $BKUPSET | awk '{print $NF}' ).conf

for CONFFILE in MAINCONF BKUPSET PLUGIN; do
  for VAR in $( grep '^\s*\(user\|password\|defaults-extra-file\)\s*=' ${!CONFFILE} ); do
    export "$VAR"
  done
done

