#!/bin/bash
# This script is for the backend database server.  The sed_balance script is DEPRECATED.
# The frontends should not have ssh-key access to the db server, but the db server requires ssh-key access to all the frontends.
# Author: Andrew Howard


EMG="\033[1;32m"
NORMAL=`tput sgr0 2> /dev/null`

# List of all the frontends (As noted in /etc/hosts)
FRONTENDS=""

# SSH port of the frontends
PORT=22

# Lock file, to force non-concurrency.  We don't want multiple syncs running at one time.
LOCK_FILE=/var/lock/sync

(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
  echo "Lock File exists - exiting"
  exit 1
fi

for SERVER in $FRONTENDS; do
  echo -e "${EMG}Syncing to $SERVER"
  echo -e "=======================================================$NORMAL"
  /usr/bin/rsync -e "ssh -p $PORT" -avzp --delete \
                 --exclude "*.user" \
                 --exclude ".cpan" \
                 --exclude ".cpcpan" \
                 --exclude "cpapachebuild" \
                 --exclude "cpeasyapache" \
                 --exclude "lost+found" \
                 --exclude "MySQL-install" \
                 --exclude "domlogs" \
                 /home root@$SERVER:/
  /usr/bin/rsync -e "ssh -p $PORT" -avzp --delete /usr/local/apache/conf root@$SERVER:/usr/local/apache/
  /usr/bin/rsync -e "ssh -p $PORT" /usr/local/apache/conf/php.conf root@$SERVER:/usr/local/apache/conf/
  /usr/bin/rsync -e "ssh -p $PORT" /etc/passwd root@$SERVER:/etc/
  /usr/bin/rsync -e "ssh -p $PORT" /etc/group root@$SERVER:/etc/

  ssh -p $PORT root@$SERVER "sed -i -f /root/sync_scripts/sed_balance /usr/local/apache/conf/httpd.conf"
  ssh -p $PORT root@$SERVER "sed -i -f /root/sync_scripts/sed_balance /usr/local/apache/conf/includes/*"

  ssh -p $PORT root@$SERVER "/etc/init.d/httpd restart"
done

echo -e "${EMG}======================================================="
echo -e "Done$NORMAL"

trap 'rm $LOCK_FILE' EXIT

