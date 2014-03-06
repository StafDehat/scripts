#!/bin/bash


LOCK_FILE=/tmp/`basename $0`.lock
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
  echo "Lock File exists - exiting"
  exit 1
fi
function cleanup {
  echo "Caught exit signal - deleting trap file"
  rm -f rm $LOCK_FILE
  exit 2
}
trap 'cleanup' 1 2 9 15 17 19 23



LOGDIR=/home/minecraft/overviewer/log
RETENTIONDAYS=7
DATE=`date +"%F-%T"`

if [ ! -d $LOGDIR ]; then
  mkdir -p $LOGDIR
fi

# 1.5 throwback
#/home/minecraft/Minecraft-Overviewer/overviewer.py --config=/home/minecraft/Minecraft-Overviewer/overviewer.conf &> $LOGDIR/$DATE.log

# 1.6+ RPM installed overviewer
/usr/bin/overviewer.py --config=/home/minecraft/overviewer/overviewer.conf &> $LOGDIR/$DATE.log

tmpwatch ${RETENTIONDAYS}d $LOGDIR


trap 'rm $LOCK_FILE' EXIT

