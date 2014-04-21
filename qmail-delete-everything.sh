#!/bin/bash

# Author: Andrew Howard

DATE=`date +%F`
#NUMDIRS=`/var/qmail/bin/qmail-showctl | grep "subdirectory split" | awk '{print $NF}' | sed 's/\.//g'`
NUMDIRS=23

echo "Stopping services"
service qmail stop
service xinetd stop

LIVEQ=/var/qmail/queue
BKUPQ=/var/qmail/queue.$DATE

cd $LIVEQ
mkdir -p $BKUPQ

echo Deleting all messages from bounce ...
#find bounce -type f -exec rm -f {} \;
mv $LIVEQ/bounce $BKUPQ/
echo Done
for dir in info intd local mess remote todo; do
  echo Deleting all messages from "$dir" ...
  #find $dir -type f -exec rm -f {} \;
  mv $LIVEQ/$dir $BKUPQ/
  echo Done
done

mkdir $LIVEQ/bounce
chown qmails:qmail $LIVEQ/bounce
chmod 700 $LIVEQ/bounce

mkdir $LIVEQ/info
chown qmails:qmail $LIVEQ/info
chmod 700 $LIVEQ/info
for x in `seq 0 22`; do
  echo "Recreating "info" structure"
  mkdir info/$x
  chmod 700 info/$x
  chown qmails:qmail info/$x
done

mkdir $LIVEQ/intd
chown qmailq:qmail $LIVEQ/intd
chmod 700 $LIVEQ/intd
for x in `seq 0 22`; do
  echo "Recreating "intd" structure"
  mkdir intd/$x
  chmod 750 intd/$x
  chown qmailq:qmail intd/$x
done

mkdir $LIVEQ/local
chown qmails:qmail $LIVEQ/local
chmod 700 $LIVEQ/local
for x in `seq 0 22`; do
  echo "Recreating "local" structure"
  mkdir local/$x
  chmod 700 local/$x
  chown qmails:qmail local/$x
done

mkdir $LIVEQ/mess
chown qmailq:qmail $LIVEQ/mess
chmod 750 $LIVEQ/mess
for x in `seq 0 22`; do
  echo "Recreating "mess" structure"
  mkdir mess/$x
  chmod 750 mess/$x
  chown qmailq:qmail mess/$x
done

mkdir $LIVEQ/remote
chown qmails:qmail $LIVEQ/remote
chmod 700 $LIVEQ/remote
for x in `seq 0 22`; do
  echo "Recreating "remote" structure"
  mkdir remote/$x
  chmod 700 remote/$x
  chown qmails:qmail remote/$x
done

mkdir $LIVEQ/todo
chown qmailq:qmail $LIVEQ/todo
chmod 750 $LIVEQ/todo
for x in `seq 0 22`; do
  echo "Recreating "todo" structure"
  mkdir todo/$x
  chmod 750 todo/$x
  chown qmailq:qmail todo/$x
done

echo "Running qfixq to ensure queue health and cleanup any remnants."
wget --no-check-certificate -O /root/qfixq https://qmail.jms1.net/scripts/qfixq
chmod +x /root/qfixq
#/root/qfixq live
/root/qfixq live empty

echo "Restarting services"
service qmail start
service xinetd start

