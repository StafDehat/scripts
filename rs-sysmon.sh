#!/bin/bash

# Force non-concurrency
LOCK_FILE=/tmp/`basename $0`.lock
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
 echo "Lock File exists - exiting"
 exit 1
fi
function cleanup {
 echo "Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
trap 'cleanup' 1 2 9 15 17 19 23


# LOGDIR must end in "/rs-sysmon"
LOGDIR=/var/log/rs-sysmon
HOURRETENTION=12


# Verify LOGDIR is something named rs-sysmon
# If it's not, we could be running tmpwatch on important content
if [ `basename $LOGDIR` != "rs-sysmon" ]; then
  echo "Error: LOGDIR is not named 'rs-sysmon'."
  echo "  We're going to run tmpwatch on the LOGDIR, which would be very bad if"
  echo "  we accidentally set LOGDIR to a directory with customer or OS content."
  echo "Exiting to avoid possibility of data loss."
  echo "Please set LOGDIR to a directory named 'rs-sysmon' in $0"
  exit 0
fi


# Verify $LOGDIR exists
if [ ! -d $LOGDIR ]; then
  mkdir -p $LOGDIR
fi


DATE=`date +"%F-%T"`

#
# ps.log
ps auxf > $LOGDIR/ps.log.$DATE

#
# mysql.log
mysql -t -e "show full processlist;" > $LOGDIR/mysql.log.$DATE

#
# netstat.log
netstat -an > $LOGDIR/netstat.log.$DATE

#
# resource.log
echo -e "\n\n\n=============== w ===============" >> $LOGDIR/resource.log.$DATE
w > $LOGDIR/resource.log.$DATE
echo -e "\n\n\n=============== df ===============" >> $LOGDIR/resource.log.$DATE
df -h > $LOGDIR/resource.log.$DATE
echo -e "\n\n\n=============== iostat ===============" >> $LOGDIR/resource.log.$DATE
iostat -Nm >> $LOGDIR/resource.log.$DATE
iostat -m >> $LOGDIR/resource.log.$DATE
echo -e "\n\n\n=============== free ===============" >> $LOGDIR/resource.log.$DATE
free >> $LOGDIR/resource.log.$DATE
echo -e "\n\n\n=============== httpd fullstatus ===============" >> $LOGDIR/resource.log.$DATE
/etc/init.d/httpd fullstatus >> $LOGDIR/resource.log.$DATE
echo -e "\n\n\n=============== top ===============" >> $LOGDIR/resource.log.$DATE
top -bn 1 >> $LOGDIR/resource.log.$DATE


#
# Clean-up
if [[ -f /usr/bin/tmpwatch || \
      -f /bin/tmpwatch ]]; then
  tmpwatch --mtime $HOURRETENTION $LOGDIR
elif [[ /usr/bin/tmpreaper || \
        /bin/tmpreaper ]]; then
  tmpreaper --mtime $HOURRETENTION $LOGDIR
else
  find $LOGDIR -maxdepth 1 -type f -mtime +$(( $HOURRETENTION / 24 )) -exec rm -f {} \;
fi


# Remove non-concurrency lock file
trap 'rm -f $LOCK_FILE' EXIT

