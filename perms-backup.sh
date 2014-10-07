#!/bin/bash

# Author: Andrew Howard

LOCK_FILE=/tmp/`basename $0`.lock
function cleanup {
 echo "Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
trap 'cleanup' 1 2 9 15 17 19 23 EXIT
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
 echo "Lock File exists - exiting"
 exit 1
fi

BACKUPDIR=/home/rack/perms-backup
RETENTIONDAYS=7

if [ ! -d $BACKUPDIR ]; then
  mkdir -p $BACKUPDIR
fi

find / -wholename '/proc' -prune -o -fprintf $BACKUPDIR/perms-backup.`date +%Y%m%d`.txt "chmod %m '%p'\nchown %u:%g '%p'\n"
getfacl --no-effective --recursive --skip-base --absolute-names / > $BACKUPDIR/facl-backup.`date +%Y%m%d`.txt

tmpwatch -m ${RETENTIONDAYS}d $BACKUPDIR

