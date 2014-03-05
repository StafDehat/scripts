#!/bin/bash

# Crypto-currency mining script
#
# chkconfig: 2345 99 01
# description: Launches a screen with a minerd process.

USERNAME=
WORKER=`hostname | cut -d. -f1`
PASSWORD=`hostname | cut -d. -f1`
DOGESERVER=stratum.dogehouse.org:8081
QUARKSERVER=mine-pool.net:3350
MINERD=~/minerd.quark
#MINERD=~/minerd.doge
SCREENNAME=crypto
PIDFILE=/var/run/.crypto.pid

function start() {
  if [ -e $PIDFILE ]; then
    echo "PID file already exists..."
    PID=`cat $PIDFILE`
    if [ `ps aux | awk '$2 ~ /^'$PID'$/ {print}' | wc -l` -gt 0 ]; then
      echo "...and process ($PID) is still running."
      echo "Stop it first.  Exiting."
      exit 1
    else
      echo "...but the process ($PID) is not running."
      echo "Removing PID file and continuing."
      rm -f $PIDFILE
    fi
  fi
  # Doge
  # screen -d -m -S dogecoin $MINERD -o stratum+tcp://$DOGESERVER -u $USERNAME.$WORKER -p $PASSWORD

  # Quark
  screen -d -m -S $SCREENNAME $MINERD -a quark -o stratum+tcp://$QUARKSERVER -u $USERNAME.$WORKER -p $WORKER

  PID=`screen -list | grep $SCREENNAME | cut -d. -f1`
  echo $PID > $PIDFILE
  echo "Miner process ($MINERD) started."
}

function stop() {
  if [ ! -e $PIDFILE ]; then
    echo "PID file does not exist.  Is the process actually running?"
    exit 1
  fi
  PID=`cat $PIDFILE`
  kill $PID
  sleep 5
  if [ -e /proc/$PID ]; then
    kill -9 $PID
  fi
  rm -f $PIDFILE
  echo "Process has been stopped, probably."
}

case $1 in
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    if [ -e $PIDFILE ]; then
      PID=`cat $PIDFILE`
      echo "PID file exists with PID $PID"
    fi
    if [ `screen -list | grep $SCREENNAME | wc -l` -gt 0 ]; then
      echo "Screen is currently running"
    fi
    ps uax | grep minerd
    exit 1
    ;;
  restart)
    stop
    start
    ;;
esac

