#!/bin/sh

# Author: Andrew Howard

NAGIOSBIN=/usr/bin/nagios
NAGIOSCONF=/etc/nagios/nagios.cfg
MONDIR=/home/nagios/monitors

echo "Checking for syntax errors..."
$NAGIOSBIN -v $NAGIOSCONF


echo ""
echo ""
echo ""
echo "Checking for files in the monitors directory..."
cd $MONDIR
find . -maxdepth 1 -type f


echo ""
echo ""
echo ""
echo "Checking for misplaced monitors..."
cd $MONDIR
grep -R host_name * | while read line; do
  CONFHOST=`echo $line | sed 's/^.*host_name\s*//'`
  echo $line | awk -F : '{print $1}' | grep -v $CONFHOST
done
for x in *; do
  ls $x/$x.cfg 2>&1 >/dev/null
done


echo ""
echo ""
echo ""
echo "Checking for multiple hosts with the same IP..."
cd $MONDIR
grep -R address * | awk '{print $NF}' | sort | uniq -c | sort -n | grep -vE '^\s*1 '


echo ""
echo ""
echo ""
echo Done

