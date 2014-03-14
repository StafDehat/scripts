#!/bin/bash

# This version only works if, in the process of removing mail from the queue, you did
# NOT change the inode number of the messages.  $BKUPQ/mess/XX/YYYYYY must be inode
# YYYYYY.  For example:
# ahoward@phoenix[~]$ ll -i mess/3/4719580
# 4719580 -rw-rw-r-- 1 ahoward ahoward 0 Mar 14 15:00 mess/3/4719580
#
# Note: The left-most (inode number) and right-most (message ID) numbers match.
# That is required for this script to work.
# Also, this script DOES delete the source messages from BKUPQ

DATE=2014-03-14
LIVEQ=/var/qmail/queue
BKUPQ=/var/qmail/queue.$DATE
NUMDIRS=23

service qmail stop
service xinetd stop

cd $BKUPQ
for DIR in info intd local mess remote todo; do
  for x in `find $DIR -type f`; do
    mv $x $LIVEQ/$x
  done
done
qfixq live

service qmail start
service xinetd start
