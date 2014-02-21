#!/bin/bash

function usage {
  echo "Usage: $0 OldName NewName"
  echo "Note:  This script assumes you have ~/.my.cnf configured correctly."
}

OLDNAME=$1
NEWNAME=$2
DATE=`date +%Y%m%d-%T`
MYSQL="mysql --defaults-file=~/.my.cnf"

# Check args
if [ $# -ne 2 ]; then
  usage
  exit 0
fi


# Test that $OLDNAME does in fact exist
if [ `$MYSQL --skip-column-names -e "show databases like '$OLDNAME';" | wc -l` -ne 1 ]; then
  echo "ERROR: Not exactly 1 database named $OLDNAME"
  usage $0
  exit 1
else
  echo "Confirmed old DB name does exist."
fi


# Test that $NEWNAME does not exist
if [ `$MYSQL --skip-column-names -e "SHOW DATABASES LIKE '$NEWNAME';" | wc -l` -ne 0 ]; then
  echo "ERROR: Desired new database already exists: $NEWNAME"
  usage $0
  exit 2
else
  echo "Confirmed new DB name does not exist"
fi


# Take a backup of current mysql privileges
(
$MYSQL mysql --skip-column-names -e "SELECT Host, User FROM user;" | while read LINE; do
  HOST=`echo $LINE | awk '{print $1}'`
  USER=`echo $LINE | awk '{print $2}'`
  $MYSQL --skip-column-names -e "SHOW GRANTS FOR '$USER'@'$HOST';" | sed -e 's/\\\\/\\/g' -e 's/$/;/'
done
) 2>/dev/null >/home/rack/mysql.privileges.$DATE


# Verify NEWNAME is valid by attempting to create the database
$MYSQL -e "CREATE DATABASE $NEWNAME;"
RETVAL=$?
if [[ $RETVAL -ne 0 ||
      `$MYSQL --skip-column-names -e "show databases like '$NEWNAME';" | wc -l` -ne 1 ]]; then
  echo "ERROR: Unable to create database $NEWNAME"
  usage $0
  exit 3
else
  echo "Confirmed new DB name is valid - created DB successfully"
fi


# Move all tables from $OLDNAME to $NEWNAME
TABLES=`$MYSQL $OLDNAME --skip-column-names -e "SHOW TABLES;"`
NUMTABLES=`echo "$TABLES" | wc -l`
for TABLE in $TABLES; do
  $MYSQL -e "RENAME TABLE $OLDNAME.$TABLE TO $NEWNAME.$TABLE;"
done


# Move permissions
$MYSQL mysql -e "UPDATE db SET Db = '$NEWNAME' WHERE Db = '$OLDNAME';"
$MYSQL -e "FLUSH PRIVILEGES;"



# Report success/failure
if [ `$MYSQL $OLDNAME --skip-column-names -e "SHOW TABLES;" | wc -l` -ne 0 ]; then
  echo "ERROR: Old database still has tables.  It shouldn't.  Not sure what went wrong."
  exit 4
elif [ `$MYSQL $NEWNAME --skip-column-names -e "SHOW TABLES;" | wc -l` -ne $NUMTABLES ]; then
  echo "ERROR: New database doesn't have $NUMTABLES tables.  Old did though, so that's weird."
  exit 5
else
  echo
  echo "Renamed database '$OLDNAME' to '$NEWNAME'"
  echo
  echo "Pretty sure everything was successful."
  echo "You'll want to double-check though."
  echo "PS: I didn't delete the old database: $OLDNAME"
  exit 0
fi

