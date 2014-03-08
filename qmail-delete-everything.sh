#!/bin/bash

echo "Stopping services"
service qmail stop
service xinetd stop

cd /var/qmail/queue

echo Deleting all messages from bounce ...
find bounce -type f -exec rm -f {} \;
echo Done
for dir in info intd local mess remote todo; do
  echo Deleting all messages from "$dir" ...
  find $dir -type f -exec rm -f {} \;
  echo Done
done

echo "Running qfixq to ensure queue health and cleanup any remnants."
wget -O /root/qfixq http://qmail.jms1.net/scripts/qfixq
chmod +x /root/qfixq
/root/qfixq live empty

echo "Restarting services"
service qmail start
service xinetd start

exit 0

for x in `seq 0 22`; do
  echo "Recreating "info" structure"
  mkdir info/$x
  chmod 750 info/$x
  chown qmails:qmail info/$x
done

for x in `seq 0 22`; do
  echo "Recreating "intd" structure"
  mkdir intd/$x
  chmod 750 intd/$x
  chown qmailq:qmail intd/$x
done

for x in `seq 0 22`; do
  echo "Recreating "local" structure"
  mkdir local/$x
  chmod 750 local/$x
  chown qmails:qmail local/$x
done

for x in `seq 0 22`; do
  echo "Recreating "mess" structure"
  mkdir mess/$x
  chmod 750 mess/$x
  chown qmailq:qmail mess/$x
done

for x in `seq 0 22`; do
  echo "Recreating "remote" structure"
  mkdir remote/$x
  chmod 750 remote/$x
  chown qmails:qmail remote/$x
done

for x in `seq 0 22`; do
  echo "Recreating "todo" structure"
  mkdir todo/$x
  chmod 750 todo/$x
  chown qmailq:qmail todo/$x
done

echo "Running qfixq to ensure queue health and cleanup any remnants."
wget -O /root/qfixq http://qmail.jms1.net/scripts/qfixq
chmod +x /root/qfixq
/root/qfixq live empty

echo "Restarting services"
service qmail start
service xinetd start

