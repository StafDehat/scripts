#!/bin/bash

# Author: Andrew Howard

mysql mysql --skip-column-names -e "select Host, User from user;" | while read x; do
 HOST=`echo $x | awk '{print $1}'`
 USER=`echo $x | awk '{print $2}'`
 mysql --skip-column-names -e "show grants for '$USER'@'$HOST';" | sed -e 's/\\\\/\\/g' -e 's/$/;/'
done 2>/dev/null
