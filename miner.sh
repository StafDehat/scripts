#!/bin/bash

# Crypto-currency mining script
#
# chkconfig: 2345 99 01
# description: Launches a screen with a minerd process.

USERNAME=
WORKER=`hostname | cut -d. -f1`
PASSWORD=`hostname | cut -d. -f1`
SHELLUSER=
DOGESERVER=stratum.dogehouse.org:8081
QUARKSERVER=mine-pool.net:3350
MINERD=`eval echo ~$SHELLUSER/minerd.quark`
#MINERD=`eval echo ~$SHELLUSER/minerd.doge`
PIDFILE=`eval echo ~$SHELLUSER/.crypto.pid`
SCREENNAME=crypto

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
  # sudo -u $SHELLUSER screen -d -m -S dogecoin $MINERD -o stratum+tcp://$DOGESERVER -u $USERNAME.$WORKER -p $PASSWORD

  # Quark
  sudo -u $SHELLUSER screen -d -m -S $SCREENNAME $MINERD -a quark -o stratum+tcp://$QUARKSERVER -u $USERNAME.$WORKER -p $WORKER

  PID=`sudo -u $SHELLUSER screen -list | grep $SCREENNAME | cut -d. -f1`
  echo $PID > $PIDFILE
  echo "Miner process ($MINERD) started."
}

function stop() {
  if [ -e $PIDFILE ]; then
    PID=`cat $PIDFILE`
    echo "Killing PID $PID"
    kill $PID
    sleep 5
    if [ -e /proc/$PID ]; then
      echo "Force-killing PID $PID"
      kill -9 $PID
    fi
    rm -f $PIDFILE
  fi
  if [ `ps aux | grep -c [m]inerd` -gt 0 ]; then
    echo "Killing all minerd processes"
    killall $MINERD
    sleep 5
  fi
  if [ `ps aux | grep -c [m]inerd` -gt 0 ]; then
    echo "Force-killing all minerd processes"
    killall -9 $MINERD
  fi
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
      if [ `ps aux | awk '$2 ~ /^'$PID'$/ {print}' | grep -c $MINERD` -gt 0 ]; then
        echo "And process $PID is our minerd process."
        if [ `sudo -u $SHELLUSER screen -list | grep -c $PID.$SCREENNAME` -gt 0 ]; then
          echo "And it's running in the right SCREEN session."
          exit 0
        fi
      fi
    fi
    echo "Something's not right - tear it down and start over, dude."
    exit 1
    ;;
  restart)
    stop
    sleep 5
    start
    ;;
esac

