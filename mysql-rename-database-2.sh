#!/bin/bash

# Author: Andrew Howard

FROMDB=$1
TODB=$2
DATE=`date +%Y%m%d-%T`

function usage {
  echo "Usage: $0 OldName NewName"
  echo "Note:  This script assumes you have ~/.my.cnf configured correctly."
}

# Test mysql connectivity
mysql -e "select @@version;" >> /dev/null
RET=$?
if [ $RET -ne 0 ]; then
  echo "ERROR: Unable to connect to MySQL service."
  usage
  exit 1
fi

# Test whether source and destination databases exist
# Source should, destination shouldn't
if [ `mysql --skip-column-names -e "show databases;" | grep -cE "^$FROMDB$"` -ne 1 ]; then
  echo "ERROR: Source database does not exist."
  usage
  exit 1
elif [ `mysql --skip-column-names -e "show databases;" | grep -cE "^$TODB$"` -ne 0 ]; then
  echo "ERROR: Destination database already exists."
  usage
  exit 1
fi


# Take a backup of current mysql privileges
(
mysql mysql --skip-column-names -e "select Host, User from user;" | while read x; do
  HOST=`echo $x | awk '{print $1}'`
  USER=`echo $x | awk '{print $2}'`
  mysql --skip-column-names -e "show grants for '$USER'@'$HOST';" | sed -e 's/\\\\/\\/g' -e 's/$/;/'
done
) 2>/dev/null >/home/rack/mysql.privileges.$DATE


# Rename tables into the new database
mysql -e "create database $TODB;"

TABLES=`mysql $FROMDB --skip-column-names -e "show tables;"`
for TABLE in $TABLES; do
  mysql -e "RENAME TABLE $FROMDB.$TABLE TO $TODB.$TABLE;"
done


# Move permissions
mysql mysql -e "UPDATE db SET Db = '$TODB' WHERE Db = '$FROMDB';"
mysql -e "FLUSH PRIVILEGES;"


# Report changes
echo "Database '$FROMDB' renamed to '$TODB'."
echo "Privileges moved to new database name."
echo 
echo "'$FROMDB' was not deleted, but should now be empty."
echo "Backup of privileges saved to /home/rack/mysql.privileges.$DATE"

