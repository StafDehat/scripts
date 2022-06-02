#!/bin/bash

# Author: Andrew Howard
# Traverse filesystem and create a file which, when executed, will set permissions
#   server-wide to what they were when this script ran.

logger "Beginning run of script: $0"

LOCK_FILE=/tmp/`basename $0`.lock
function cleanup {
 logger "Exiting script: $0"
 echo "Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
trap 'cleanup' 1 2 9 15 17 19 23 EXIT
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
 echo "Lock File exists - exiting"
 logger "Lock File exists - exiting script: $0"
 exit 1
fi

BACKUPDIR=/home/rack/perms-backup
RETENTIONDAYS=7
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

if [ ! -d $BACKUPDIR ]; then
  mkdir -p $BACKUPDIR
fi

find / -wholename '/proc' -prune -o -fprintf $BACKUPDIR/perms-backup.`date +%Y%m%d`.txt "chown -h %u:%g '%p'\nchmod %m '%p'\n"
getfacl --no-effective --recursive --skip-base --absolute-names / > $BACKUPDIR/facl-backup.`date +%Y%m%d`.txt

#
# Clean-up
if which tmpwatch &>/dev/null; then
  tmpwatch -m ${RETENTIONDAYS}d $BACKUPDIR
elif which tmpreaper &>/dev/null; then
  tmpreaper --mtime ${RETENTIONDAYS}d $BACKUPDIR
else
  find ${BACKUPDIR} -maxdepth 1 -type f -mtime +${RETENTIONDAYS} -exec rm -f {} \;
fi



