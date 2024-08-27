#!/bin/bash
# Author: Andrew Howard

###############################################################################
# You need to set these variables
# Note: This script won't fit most cases perfectly.  Be sure to edit the
#       script and intelligently cron to fit your backup frequency.
###############################################################################
BACKUPDIR=/backup
BACKUPTARGET=/tmp/sessiondata

# Define how many backups to keep of each interval
MINUTES=120
HOURS=48
DAYS=14
WEEKS=8
MONTHS=24
YEARS=10
###############################################################################

# Ensure non-concurrency
LOCK_FILE=/tmp/`basename $0`.lock
function cleanup {
 echo "Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
trap 'cleanup' 1 2 9 15 19 23 EXIT
trap 'cleanup' 1 2 9 15 19 23 EXIT
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
 echo "Lock File exists - exiting"
 exit 1
fi
# End non-concurrency check

# Create directory structure if not exists
mkdir -p $BACKUPDIR/minutely \
         $BACKUPDIR/hourly \
         $BACKUPDIR/daily \
         $BACKUPDIR/weekly \
         $BACKUPDIR/monthly \
         $BACKUPDIR/yearly


# Create/compress the backup
DATE=$( date +"%F-%H:%M" )
TARGETDIR=$( dirname $BACKUPTARGET )
TARGETFILE=$( basename $BACKUPTARGET )
tar -czf $BACKUPDIR/ -C $TARGETDIR $BACKUPDIR/$TARGETFILE.$DATE.tgz


# Always do minutely
ln $BACKUPDIR/$TARGETFILE.$DATE.tgz $BACKUPDIR/minutely/$TARGETFILE.$DATE.tgz
tmpwatch -m ${MINUTES}m $BACKUPDIR/minutely
# Check if this is the on-the-hour run
if [ $( date +%M ) -eq 00 ]; then
  # Hourly
  ln $BACKUPDIR/$TARGETFILE.$DATE.tgz $BACKUPDIR/hourly/$TARGETFILE.$DATE.tgz
  tmpwatch -m ${HOURS}h $BACKUPDIR/hourly
  # Check if this is the midnight-hour run
  if [ $( date +%H ) -eq 00 ]; then
    # Daily
    ln $BACKUPDIR/$TARGETFILE.$DATE.tgz $BACKUPDIR/daily/$TARGETFILE.$DATE.tgz
    tmpwatch -m ${DAYS}d $BACKUPDIR/daily
    # Check if this is the Sunday run
    if [ $( date +%w ) -eq 0 ]; then
      # Weekly
      ln $BACKUPDIR/$TARGETFILE.$DATE.tgz $BACKUPDIR/weekly/$TARGETFILE.$DATE.tgz
      tmpwatch -m $(( $WEEKS * 7 ))d $BACKUPDIR/weekly
    fi #End weekly
    # Check if this is the 1st of Month
    if [ $( date +%d ) -eq 01 ]; then
      # Monthly
      ln $BACKUPDIR/$TARGETFILE.$DATE.tgz $BACKUPDIR/monthly/$TARGETFILE.$DATE.tgz
      tmpwatch -m $(( $MONTHS * 31 ))d $BACKUPDIR/monthly
      # Check if this is January
      if [ $(date +%m ) -eq 01 ]; then
        # Yearly
        ln $BACKUPDIR/$TARGETFILE.$DATE.tgz $BACKUPDIR/yearly/$TARGETFILE.$DATE.tgz
        tmpwatch -m $(( $YEARS * 365 ))d $BACKUPDIR/yearly
      fi #End Yearly
    fi #End Monthly
  fi #End Daily
fi #End Hourly
# End Minutely

# Now we're done with the temp location of the backup
rm -f $BACKUPDIR/$TARGETFILE.$DATE.tgz

