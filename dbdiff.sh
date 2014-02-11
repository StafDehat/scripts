#!/bin/bash

# Colours!
K="\033[0;30m"    # black
R="\033[0;31m"    # red
G="\033[0;32m"    # green
Y="\033[0;33m"    # yellow
B="\033[0;34m"    # blue
P="\033[0;35m"    # purple
C="\033[0;36m"    # cyan
W="\033[0;37m"    # white
EMK="\033[1;30m"
EMR="\033[1;31m"
EMG="\033[1;32m"
EMY="\033[1;33m"
EMB="\033[1;34m"
EMP="\033[1;35m"
EMC="\033[1;36m"
EMW="\033[1;37m"
NORMAL=`tput sgr0 2> /dev/null`


function usage() {
  echo "Usage: $0 ProdDB TestDB"
}

if [ -e ~/.my.cnf ]; then
  MYSQL="$MYSQL --defaults-file=~/.my.cnf"
fi
MYSQL="mysql --skip-column-names"

$MYSQL -e "show databases;" >/dev/null
if [ $? -ne 0 ]; then
  echo "ERROR: Unable to connect to MySQL service."
  exit 2
fi

if [ $# -ne 2 ]; then
  usage
  exit 1
fi

PRODDB=$1
TESTDB=$2

$MYSQL $PRODDB -e "show tables;" >/dev/null
if [ $? -ne 0 ]; then
  echo "ERROR: Unable to access database '$PRODDB'"
  usage
  exit 3
fi

$MYSQL $TESTDB -e "show tables;" >/dev/null
if [ $? -ne 0 ]; then
  echo "ERROR: Unable to access database '$TESTDB'"
  usage
  exit 3
fi


# Diff the "show tables", output create table statements, exit
PRODUNIQ=`comm -23 <($MYSQL $PRODDB -e "show tables;" | sort) \
                   <($MYSQL $TESTDB -e "show tables;" | sort)`
TESTUNIQ=`comm -13 <($MYSQL $PRODDB -e "show tables;" | sort) \
                   <($MYSQL $TESTDB -e "show tables;" | sort)`
if [[ ! -z "$PRODUNIQ" || ! -z "$TESTUNIQ" ]]; then
  echo
  echo "Differences exist in 'SHOW TABLES' output."
  echo "Not comparing fields - make table lists identical first."
  echo
  echo "Run the following to change '$TESTDB' to match '$PRODDB':"
  echo -ne "$C"
  echo "USE $TESTDB;"
  for TABLE in $TESTUNIQ; do
    echo "DROP TABLE $TABLE;"
  done
  for TABLE in $PRODUNIQ; do
    echo -e `$MYSQL $PRODDB --skip-column-names -e "show create table $TABLE;" | perl -pe 's/.*(CREATE TABLE.*)/\1;/'`    
  done
  echo -ne "$NORMAL"
  echo

  echo
  echo "Run the following to change '$PRODDB' to match '$TESTDB':"
  echo -ne "$P"
  echo "USE $PRODDB;"
  for TABLE in $PRODUNIQ; do
    echo "DROP TABLE $TABLE;"
  done
  for TABLE in $TESTUNIQ; do
    echo -e `$MYSQL $TESTDB --skip-column-names -e "show create table $TABLE;" | perl -pe 's/.*(CREATE TABLE.*)/\1;/'`    
  done
  echo -ne "$NORMAL"
  echo

  exit 0
fi



TABLES=`$MYSQL $PRODDB -e "show tables;"`
for TABLE in $TABLES; do
  # Stuff in $PRODDB but not in $TESTDB
  PRODUNIQ=`comm -23 <($MYSQL $PRODDB -e "describe $TABLE;" | sort) \
                     <($MYSQL $TESTDB -e "describe $TABLE;" | sort)`
  # Stuff in $TESTDB but not in $PRODDB
  TESTUNIQ=`comm -13 <($MYSQL $PRODDB -e "describe $TABLE;" | sort) \
                     <($MYSQL $TESTDB -e "describe $TABLE;" | sort)`

  if [ ! -z "$PRODUNIQ" ]; then
    FIELD=`echo "$PRODUNIQ" | awk '{print $1}'`
    if [ `$MYSQL $TESTDB -e "describe $TABLE" | grep -c "^$FIELD\s"` -eq 0 ]; then
      # Field exists in only ProdDB
      FIELDDESC=$( $MYSQL $PRODDB -e "show create table $TABLE;" \
                   | perl -pe 's/^.*(`'$FIELD'`.*?),.*$/\1/' )
      # Record ALTER TABLE statements to make things identical
      MODTEST="${MODTEST}ALTER TABLE $TABLE ADD $FIELDDESC;\n"
      MODPROD="${MODPROD}ALTER TABLE $TABLE DROP COLUMN $FIELD;\n"
    else
      # Field exists in both, but differently
      FIELDDESC=$( $MYSQL $PRODDB -e "show create table $TABLE;" \
                   | perl -pe 's/^.*(`'$FIELD'`.*?),.*$/\1/' )
      MODTEST="${MODTEST}ALTER TABLE $TABLE MODIFY COLUMN $FIELDDESC;\n"
      FIELDDESC=$( $MYSQL $TESTDB -e "show create table $TABLE;" \
                   | perl -pe 's/^.*(`'$FIELD'`.*?),.*$/\1/' )
      MODPROD="${MODPROD}ALTER TABLE $TABLE MODIFY COLUMN $FIELDDESC;\n"
    fi
  fi

  if [ ! -z "$TESTUNIQ" ]; then
    FIELD=`echo "$TESTUNIQ" | awk '{print $1}'`
    if [ `$MYSQL $PRODDB -e "describe $TABLE" | grep -c "^$FIELD\s"` -eq 0 ]; then
      # Field exists in only TestDB
      FIELDDESC=$( $MYSQL $TESTDB -e "show create table $TABLE;" \
                   | perl -pe 's/^.*(`'$FIELD'`.*?),.*$/\1/' )
      # Record ALTER TABLE statements to make things identical
      MODPROD="${MODPROD}ALTER TABLE $TABLE ADD $FIELDDESC;\n"
      MODTEST="${MODTEST}ALTER TABLE $TABLE DROP COLUMN $FIELD;\n"
    fi
  fi
done


if [ ! -z "$MODTEST" ]; then
  echo
  echo "Recommended queries to change '$TESTDB' to align with '$PRODDB':"
  echo -ne "$C"
  echo "USE $TESTDB;"
  echo -e "$MODTEST"
  echo -ne "$NORMAL"
  echo
  echo
  echo "Recommended queries to change '$PRODDB' to align with '$TESTDB':"
  echo -ne "$P"
  echo "USE $PRODDB;"
  echo -e "$MODPROD"
  echo -ne "$NORMAL"
  echo
else
  echo "Databases '$PRODDB' and '$TESTDB' already have identical structure."
fi


