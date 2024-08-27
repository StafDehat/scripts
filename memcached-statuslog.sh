#!/bin/bash
# Author: Andrew Howard
# A race-condition-safe bash script wrapper that will ensure this script
# runs non-concurrently with other instances of itself.

LOCK_FILE=/tmp/`basename $0`.lock
function cleanup {
 echo "Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
trap 'cleanup' 1 2 9 15 19 23 EXIT
trap 'cleanup' 1 2 9 15 19 23 EXIT
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
 echo "Lock File exists - exiting"
 exit 1
fi

LOGDIR=/var/log/memcached

if [ $( basename $LOGDIR ) != "memcached" ]; then
  echo "LOGDIR must be named 'memcached'." >&2
  echo "I insist on this as a safety check, because we're going" >&2
  echo "  to run tmpwatch on it." >&2
  exit
fi
if [ ! -d $LOGDIR ]; then
  if [ $( id -u ) -eq 0 ]; then
    mkdir -p $LOGDIR
  else
    echo "$0: Log directory ($LOGDIR) does not exist" >&2
    exit
  fi
fi

cat << EOF >$LOGDIR/$( date +"%F-%T" )
$( date )

$( echo stats | nc localhost 11211 )
EOF

tmpwatch -m 24 $LOGDIR

