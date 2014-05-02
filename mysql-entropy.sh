#!/bin/bash


DB=ecom
HOST=localhost
PORT=3306
USER=root
PASS=Cnw49uNyVp
FREQ=5
MYSQL="mysql --skip-column-names --protocol=TCP -h $HOST -P $PORT -u$USER -p$PASS"
TOGGLE=/home/lab/entropy

# Pause:    echo 0 > $TOGGLE
# Run live: echo 1 > $TOGGLE
# Exit:     echo 2 > $TOGGLE
# Will fail to Pause status


#
# Create the necessary structure
$MYSQL -e "CREATE DATABASE IF NOT EXISTS $DB;"
$MYSQL $DB -e "CREATE TABLE IF NOT EXISTS orders (
                 id    int(11)  NOT NULL AUTO_INCREMENT,
                 count int(16)  NOT NULL,
                 time  datetime NOT NULL,
                 PRIMARY KEY (id)
               ) ENGINE=MyISAM DEFAULT CHARSET=latin1;"
$MYSQL $DB -e "CREATE TABLE IF NOT EXISTS products (
                 id       int(11)     NOT NULL AUTO_INCREMENT,
                 stock    int(16)     NOT NULL,
                 itemCode varchar(20) NOT NULL,
                 PRIMARY KEY (id)
               ) ENGINE=MyISAM DEFAULT CHARSET=latin1;"


#
# Populate the 'products' table
if [ $( $MYSQL $DB -e "select count(id) from products;" ) -eq 0 ]; then
  itemcodes=$( head /dev/urandom | hexdump | head -50 | awk '{print $2$3$4$5}' )
  for code in $itemcodes; do
    $MYSQL $DB -e "INSERT INTO products (stock, itemCode) VALUES ($RANDOM, '$code')"
  done
fi


#
# Inserts
while true; do
  if [ `cat $TOGGLE` -eq 2 ]; then
    exit
  elif [ `cat $TOGGLE` -eq 1 ]; then
    if [ $( $MYSQL $DB -e "SELECT count(id) FROM orders;" ) -lt 30 ]; then
      $MYSQL $DB -e "INSERT INTO orders (count, time) VALUES ($RANDOM, now())"
    fi
  fi
  sleep $(( $RANDOM % $FREQ ))
done &

#
# Updates
while true; do
  if [ -f $TOGGLE ]; then
    if [ `cat $TOGGLE` -eq 2 ]; then
      exit
    elif [ `cat $TOGGLE` -eq 1 ]; then
      # Replication-unsafe query
      $MYSQL $DB -e "UPDATE orders SET count = '$RANDOM' ORDER BY RAND() LIMIT 1;"
    fi
  fi
  sleep $(( $RANDOM % $FREQ ))
done &
while true; do
  if [ -f $TOGGLE ]; then
    if [ `cat $TOGGLE` -eq 2 ]; then
      exit
    elif [ `cat $TOGGLE` -eq 1 ]; then
      $MYSQL $DB -e "UPDATE products SET stock = stock - 1 WHERE stock > 0 ORDER BY RAND() LIMIT 1;"
    fi
  fi
  sleep $(( $RANDOM % $FREQ ))
done &
while true; do
  if [ -f $TOGGLE ]; then
    if [ `cat $TOGGLE` -eq 2 ]; then
      exit
    elif [ `cat $TOGGLE` -eq 1 ]; then
      $MYSQL $DB -e "UPDATE products SET stock = stock + 1 WHERE stock < 30000 ORDER BY RAND() LIMIT 1;"
    fi
  fi
  sleep $(( $RANDOM % $FREQ ))
done &

#
# Deletes
while true; do
  if [ -f $TOGGLE ]; then
    if [ `cat $TOGGLE` -eq 2 ]; then
      exit
    elif [ `cat $TOGGLE` -eq 1 ]; then
      if [ $( $MYSQL $DB -e "SELECT count(id) FROM orders;" ) -gt 20 ]; then
         # Replication-unsafe query
         $MYSQL $DB -e "DELETE FROM orders WHERE count < '30000' ORDER BY RAND() LIMIT 1;"
      fi
    fi
  fi
  sleep $(( $RANDOM % $FREQ ))
done &

