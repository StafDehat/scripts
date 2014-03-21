#!/bin/bash

# Author: Andrew Howard

# For nagios clusters, push monitoring config for a specific host out to the polling slave.

usage () {
  ME=$0
  echo "Usage: $ME OPTION"
  echo "OPTION: -H hostname   :Reload host 'hostname'"
  echo "        -c            :Reload host '.' (current directory)"
  echo "        -h            :Print this help"
}

# Handle command-line arguments
while getopts ":H:c" arg
do
  case $arg in
    H  ) # Ensure specified host exists in nagios
         HOST=$OPTARG
         if [ ! -d /usr/local/nagios/etc/monitoring/monitors/$HOST ]; then
           echo "Error: Host '$HOST' does not exist!"
           exit 1
         fi ;;
    c  ) # Ensure `pwd` exists as a host in nagios
         HOST=`basename $(pwd)`
         if [ ! -d /usr/local/nagios/etc/monitoring/monitors/$HOST ]; then
           echo "Error: Host '$HOST' does not exist!"
           exit 1
         fi ;;
    *  ) usage
         exit 1 ;;
       # Default
  esac
done

# Catch cases such as "resync-host.sh host.blah.com"
# Since there are no options specified, it would bypass the above 'while getopts' loop without setting $HOST at all.
if [ -z $HOST ]; then
  usage
  exit 1
fi

# We have a valid host.  If it's already on the slaves replace it, otherwise put it on one.
cd /usr/local/nagios/etc/monitoring/slaves
if [ `find . -name $HOST | wc -l` -ne 1 ]; then
  SLAVE=`echo * | cut -d\  -f1`
else
  SLAVE=`find . -name $HOST | cut -d/ -f2`
fi

rm -rf /usr/local/nagios/etc/monitoring/slaves/$SLAVE/$HOST
cp -pR /usr/local/nagios/etc/monitoring/monitors/$HOST /usr/local/nagios/etc/monitoring/slaves/$SLAVE/
ssh $SLAVE "service nagios reload"

