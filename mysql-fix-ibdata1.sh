#!/bin/bash

# This is handy for getting a count of your ENGINE usage:
mysql -e "select engine,count(*),sum(index_length+data_length)/1024/1024 from information_schema.tables group by engine;"


# Get a list of DBs
DBS=$( mysql -Ne "show databases;" )

# Get a list of all the InnoDB stuff
for DB in $DBS; do
  TABLES=$( mysql $DB -Ne "show table status where engine like 'InnoDB';" | awk '{print $1}' )
  for TABLE in $TABLES; do
    echo "$DB.$TABLE"
  done
done > /home/rack/innodb.tables

# Convert all InnoDB to MyISAM
# Note: At least one will fail.  Just make sure the ones that fail are the ones that also don't really exist.
#  If any important InnoDB tables actually do fail, just dump those tables specifically.
for TBL in $( cat /home/rack/innodb.tables ); do
  echo -n "Converting $TBL from InnoDB to MyISAM..."
  mysql -e "ALTER TABLE $TBL ENGINE=MyISAM;"
  echo "Conversion complete."
done

# Now shutdown MySQL and nuke ibdata1, ib_logfile*
# Start MySQL - read error logs.  It should be healthy, with newly generated InnoDB files.

# Convert all the formerly-InnoDB tables back to InnoDB
for TBL in $( cat /home/rack/innodb.tables ); do
  echo -n "Converting $TBL from MyISAM to InnoDB..."
  mysql -e "ALTER TABLE $TBL ENGINE=InnoDB;"
  echo "Conversion complete."
done

