#!/bin/bash

# Author: Andrew Howard

DBS=`echo "show databases\G" | mysql | grep Database | sed -e 's/Database: //'`

for DB in $DBS; do
  TABLES=`mysql $DB -e "show tables;" | grep -v Tables_in_$DB`
  for TABLE in $TABLES; do
    FIELDS=`mysql $DB -e "describe $TABLE \G;" | grep 'Field: ' | awk '{print $2}'`
    FIELDS=$(for FIELD in $FIELDS; do
      FIELD=`mysql $DB -e "describe $TABLE;" | grep -E "^\s*$FIELD"`
      if [[ `echo $FIELD | awk '{ if($4 == "PRI") print $0 }' | wc -l` -gt 0 &&
            `echo $FIELD | awk '{print $2}' | grep int | wc -l` -gt 0 ]]; then
        echo $FIELD | awk '{print $1}'
      fi
    done)

    for FIELD in $FIELDS; do
      # DB, TABLE, and FIELD are all pointing to a numeric primay key at this point
      COLTYPE=`mysql $DB -e "describe $TABLE;" | grep -E "^\s*$FIELD" | awk '{print $2}'`
      echo "mysql $DB -e ALTER TABLE $TABLE MODIFY $FIELD $COLTYPE NOT NULL auto_increment;"
    done
  done
done

