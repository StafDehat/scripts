#!/bin/bash

# This version of the reinject script is to be used when the messages in the BKUPQ directory
# no longer have their original inode number, and/or are not on the same filesystem as the
# LIVEQ directory.
# ie: After a mv, the message ID won't match the inode number of $LIVEQ/mess/XX/YYYYYY
# Also, this script does not delete the source messages from the $BKUPQ

DATE=2014-03-14
LIVEQ=/var/qmail/queue
BKUPQ=/var/qmail/queue.$DATE
NUMDIRS=23


service qmail stop
service xinetd stop


for x in $BKUPQ/mess/*/*; do
  OLDID=`basename $x`
  OLDNUMDIR=`basename $(dirname $x)`

  # Need to touch a file to get a known, unused inode
  touch $LIVEQ/mess/tmpfile
  chmod 750 $LIVEQ/mess/tmpfile
  chown qmailq:qmail $LIVQ/mess/tmpfile
  INODENUM=`ll -i $LIVEQ/mess/tmpfile | awk '{print $1}'`

  # Now we know the new message ID - rename the file
  NEWID=$INODENUM
  NEWNUMDIR=`echo $(( $NEWID % 23 ))`
  mv $LIVEQ/mess/tmpfile $LIVEQ/mess/$NEWNUMDIR/$NEWID

  # Populate the content of the new message file
  cat $BKUPQ/mess/$OLDNUMDIR/$OLDID > $LIVEQ/mess/$NEWNUMDIR/$NEWID

  for y in $BKUPQ/*/$OLDNUMDIR/$OLDID; do 
    FILE=`echo $y | cut -d/ -f5-`
    if [ `echo $FILE | cut -d/ -f1` != "mess" ]; then
      cp -p $BKUPQ/$FILE $LIVEQ/$FILE
    fi
  done
done


wget -O /root/qfixq http://qmail.jms1.net/scripts/qfixq
chmod +x /root/qfixq
/root/qfixq live


service qmail start
service xinetd start
