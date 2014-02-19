#!/bin/bash

ADMINPASS=`cat /etc/psa/.psa.shadow`
USERS=`mysql -uadmin -p$ADMINPASS -e "use psa; select * from db_users;" | grep -E '^[0-9]' | awk '{print $2}'`
for USER in $USERS; do
  ACCOUNTID=`mysql -uadmin -p$ADMINPASS -e "use psa; select * from db_users;" | sed -n "/\\s$USER\\s/p" | awk '{print $3}'`
  DBID=`mysql -uadmin -p$ADMINPASS -e "use psa; select * from db_users;" | sed -n "/\\s$USER\\s/p" | awk '{print $4}'`

  PASSWORD=`mysql -uadmin -p$ADMINPASS -e "use psa; select * from accounts;" | sed -n "/^$ACCOUNTID\\s/p" | awk '{print $3}'`
  DATABASE=`mysql -uadmin -p$ADMINPASS -e "use psa; select * from data_bases;" | sed -n "/^$DBID\\s/p" | awk '{print $2}'`

  echo "GRANT ALL ON $DATABASE.* TO '$USER'@'localhost' IDENTIFIED BY '$PASSWORD';"
done

