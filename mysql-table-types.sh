#!/bin/bash

# This script prints all InnoDB tables in the form:
# [database] [table]
# To see just the databases containing InnoDB tables, run this script
# and pipe its output to awk and uniq as such:
# ./list-innodb-tables.sh | awk '{print $1}' | uniq

#dbs=`echo "show databases\G" | mysql | grep Database | sed -e 's/Database: //'`

#for db in $dbs; do
#  for table in `mysql -e "use $db; show table status;" | grep InnoDB | awk '{print $1}'`; do
#    echo -n "$db "
#    echo $table
#  done
#done

select engine,count(*),sum(index_length+data_length)/1024/1024 from information_schema.tables group by engine;
