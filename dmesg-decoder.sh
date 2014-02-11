#!/bin/bash
# 1) Add this line to /etc/rc.local:
#    echo 1 > /sys/module/printk/parameters/time
# 2) Rename /bin/dmesg to /bin/dmesg.orig
# 3) Place this script at /bin/dmesg and make it executable.

dmesg.orig $@ | \
while read LINE; do
  if [[ "$LINE" =~ ^\[[0-9][0-9]*\.[0-9][0-9]*\] ]]; then
    SECS=`echo $LINE | cut -d. -f1 | cut -d[ -f2`
    MSECS=`echo $LINE | cut -d] -f1 | cut -d. -f2`
    RESTOFLINE=`echo $LINE | cut -d] -f2-`
    NOW=`date +%s`
    UPTIME=`cat /proc/uptime | cut -d. -f1`
    BOOTTIME=$(( $NOW - $UPTIME ))
    LOGTIME=$(( $BOOTTIME + $SECS ))
    echo `date +"%F %T" -d@"$LOGTIME"` $RESTOFLINE
  else
    echo $LINE
  fi
done

