#!/bin/bash

# Author: Andrew Howard

DATE=`date +"%F-%T"`
LOGFILE=/var/log/status.log

LOCK_FILE=/var/lock/`basename $0`
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
  logger "$0: Lock File exists - aborting run at $DATE"
  exit 1
fi
trap 'rm $LOCK_FILE' EXIT


logger "$0: Initiating run at $DATE"

(
  echo -n "$DATE: "

  if [ -d /mnt/nfs/images ]; then
    echo -n "NFS:OK "
  else
    echo -n "NFS:Failure "
  fi

  curl localhost/test.html &>/dev/null
  if [ $? -eq 0 ]; then
    echo -n "HTTP:OK "
  else
    echo -n "HTTP:Failure "
  fi

  echo
) >> $LOGFILE

