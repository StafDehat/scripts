#!/bin/bash

PLAYERNAME=
PASSWORD=
SCREENNAME=multirpg
SCREENLOCK=

function command {
  # Attempt to grab a lock on the screen session
  (set -C; : > $SCREENLOCK) 2> /dev/null
  while [ $? != "0" ]; do
    echo "Lock File exists - waiting"
    sleep 60
    (set -C; : > $SCREENLOCK) 2> /dev/null
  done
  # Write to the screen
  wall "Running on #multirpg in 10 seconds: $1"
  sleep 10
  screen -S $SCREENNAME -X stuff "/msg multirpg $1"
  screen -S $SCREENNAME -X stuff $'\012'
  # Release the screen session lock
  rm -f $SCREENLOCK
}

