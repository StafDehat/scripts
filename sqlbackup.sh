#!/bin/bash

# Author: Andrew Howard

LOCK_FILE=/tmp/`basename $0`.lock
function cleanup {
 echo "Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
trap 'cleanup' 1 2 9 15 17 19 23 EXIT
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
 echo "Lock File exists - exiting"
 exit 1
fi

SQLUSER=xxxxxxxx
SQLPASS="xxxxxxxx"
BACKUPDIR=/home/rack/mysqldump
DATE=`date +%Y-%m-%d`
RETENTION=3
MYSQL="/usr/bin/mysql -u$SQLUSER -p$SQLPASS"
MYSQLDUMP="/usr/bin/mysqldump -u$SQLUSER -p$SQLPASS"
LOCK_FILE=/var/lock/`basename $0`


#
# Verify backup directory exists
umask 0066
if [[ ! -d $BACKUPDIR/$DATE ]]; then
  mkdir -p $BACKUPDIR/$DATE
  chmod 0700 $BACKUPDIR/$DATE
fi

#
#  Get list of MySQL databases
DBS=`$MYSQL --skip-column-names -e "show databases;"`

#
# Back 'em up
for DB in $DBS; do
  if [ $DB != "information_schema" ]; then
    $MYSQLDUMP -Q $DB > $BACKUPDIR/$DATE/$DB.sql
    gzip $BACKUPDIR/$DATE/$DB.sql
  fi
done


#
# Backup users too
$MYSQL mysql --skip-column-names -e "select Host, User from user;" | \
while read x; do
  HOST=`echo $x | awk '{print $1}'`
  USER=`echo $x | awk '{print $2}'`
  mysql --skip-column-names -e "show grants for '$USER'@'$HOST';" | sed -e 's/\\\\/\\/g' -e 's/$/;/'
done > $BACKUPDIR/$DATE/sql-perms.sql


#
# Housekeeping.  Delete any file older than $RETENTION days
/usr/sbin/tmpwatch --mtime $(( 24 * $RETENTION )) $BACKUPDIR


