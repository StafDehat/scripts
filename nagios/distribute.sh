#!/bin/bash

# Author: Brandon Ewing

LOCK_FILE=/var/lock/distribute
SLAVEDIR=/usr/local/nagios/etc/monitoring/slaves
MONDIR=/usr/local/nagios/etc/monitoring/dynamic

#
# Capture Ctrl-C, clean-up, and warn of potential disaster
control_c() {
  echo "Caught interrupt."
  echo "Cleaning up lock file."
  rm -f $LOCK_FILE
  echo "WARNING: Monitors may be in inconsistent state!"
  echo "It is *strongly* advised that this script be run again, immediately, to completion."
  trap 'rm $LOCK_FILE' EXIT
}

#
# Script to alert techlist of an abort due to lock file existing.
lock_fail_alert() {
  TO="inbox@fqdn"
  FROM="inbox@fqdn"
  SUBJECT="WARNING: distribute.sh aborted!"
  sendmail -t -f$FROM <<EOF
To: $TO
Reply-to: $FROM
From: $FROM
Subject: $SUBJECT
The distribute.sh script on Atma normally assigns monitors to the nagios
slave servers.  The script just attempted to execute, but the lock file
$LOCK_FILE exists.

Please reference the following timestamp on the lock file against the
current date/time.  The lock file should never be more than a few minutes
old.
`ls -l $LOCK_FILE 2>&1`

If the lock file is more than a few minutes old, you should check for
instances of the distribute.sh script in 'ps aux', kill them all, then
manually delete the lock file.  After doing so, please run distribute.sh
manually to ensure the slaves are properly configured.
.
EOF
}

#
# Prevent user from manually killing script
trap control_c SIGINT

(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
  echo "Lock File exists - exiting"
  lock_fail_alert
  exit 1
fi

#  First, get our list of slaves
cd $SLAVEDIR
slaves=( * )
numslaves=${#slaves[@]}


# Clean out the slaves
find $SLAVEDIR -type d -mindepth 2 | xargs rm -rf

# Clean up permissions
/bin/chown -R nagios. $MONDIR

# x tracks our round robin
x=1
# Distribute the monitors among the slaves
cd $MONDIR
for host in *; do
  mod=$(($x % $numslaves))
  cp -ra $MONDIR/${host} $SLAVEDIR/${slaves[$mod]}
  x=$(($x + 1))
done

# Distribute the slaves among the slaves - round robin, so we're sure no slave monitors itself.
for x in `seq 1 $numslaves`; do
  mod1=$(( $x % $numslaves ))
  mod2=$(( ($x + 1) % $numslaves ))
  cp -ra $MONDIR/../static/${slaves[$mod1]}.rootmypc.net $SLAVEDIR/${slaves[$mod2]}/
done

# HUP DA NAGIOS and sync .ssh/resolv.conf
sleep 5
for i in ${slaves[@]}
do
  echo -e "\nRestarting $i"
  rsync -plar -e ssh /home/nagios/.ssh ${i}:/home/nagios/
  rsync -plar -e ssh /etc/resolv.conf ${i}:/etc/
  ssh $i "/sbin/service nagios stop"
  sleep 1
  STRAGGLERS=`ssh $i "ps axu | grep nagios | grep -v grep" | awk '{print $2}' | xargs echo -n`
  if [ ! -z "$STRAGGLERS" ]; then
    echo "Killing processes that failed to exit"
    ssh $i "kill -9 $STRAGGLERS"
  fi
  ssh $i "/sbin/service nagios start &"
done

# Reload nagios on Atma
/etc/init.d/nagios reload

trap 'rm $LOCK_FILE' EXIT

