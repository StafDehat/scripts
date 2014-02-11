#!/bin/bash

function usage() {
  echo "Usage: $0 OldName NewName"
}

OLDNAME=$1
NEWNAME=$2


if [ `mysql --skip-column-names -e "show databases like '$OLDNAME';" | wc -l` -ne 1 ]; then
  echo "ERROR: Not exactly 1 database named $OLDNAME"
  usage $0
  exit 1
else
  echo "Confirmed old DB name does exist."
fi

if [ `mysql --skip-column-names -e "SHOW DATABASES LIKE '$NEWNAME';" | wc -l` -ne 0 ]; then
  echo "ERROR: Desired new database already exists: $NEWNAME"
  usage $0
  exit 2
else
  echo "Confirmed new DB name does not exist"
fi

`mysql -e "CREATE DATABASE $NEWNAME;"`
RETVAL=$?
if [[ $RETVAL -ne 0 ||
      `mysql --skip-column-names -e "show databases like '$NEWNAME';" | wc -l` -ne 1 ]]; then
  echo "ERROR: Unable to create database $NEWNAME"
  usage $0
  exit 3
else
  echo "Confirmed new DB name is valid - created DB successfully"
fi


TABLES=`mysql $OLDNAME --skip-column-names -e "SHOW TABLES;"`
NUMTABLES=`echo "$TABLES" | wc -l`
for TABLE in $TABLES; do
  mysql -e "RENAME TABLE $OLDNAME.$TABLE TO $NEWNAME.$TABLE;"
done


if [ `mysql $OLDNAME --skip-column-names -e "SHOW TABLES;" | wc -l` -ne 0 ]; then
  echo "ERROR: Old database still has tables.  It shouldn't.  Not sure what went wrong."
  exit 4
elif [ `mysql $NEWNAME --skip-column-names -e "SHOW TABLES;" | wc -l` -ne $NUMTABLES ]; then
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

