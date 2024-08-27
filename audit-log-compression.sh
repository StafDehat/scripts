#!/bin/bash
# Author: Andrew Howard

# Recommended: Run this via cronjob, every day at midnight (0 0 * * *).
# Optional: Set max_log_file_action = ignore in auditd.conf, and you'll
#   get a single log file per day.


# Begin non-concurrency wrapper
# A race-condition-safe bash script wrapper that will ensure this script
# runs non-concurrently with other instances of itself.
logger "$0: Starting execution"
LOCK_FILE=/tmp/`basename $0`.lock
function cleanup {
 logger "$0: Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
trap 'cleanup' 1 2 9 15 19 23 EXIT
trap 'cleanup' 1 2 9 15 19 23 EXIT
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
 logger "$0: Lock File exists - exiting"
 exit 1
fi
# End non-concurrency wrapper

#
# Do script-wide things
cd /var/log/audit/
YESTERDAY=$( date +%F -d "yesterday" )

# Begin redundancy check
# Script should only be run once daily, or it could overwrite previous
# audit logs.  Verify no 'yesterday' logs currently exist, else exit.
COUNT=$( ls -1U audit.log.$YESTERDAY.* 2>/dev/null | wc -l )
if [ $COUNT -ne 0 ]; then
  logger "$0: ERROR - Yesterday's logs already rotated."
  echo "ERROR: Yesterday's logs already rotated."
  echo "Script must have already run today - exiting."
  exit 1
fi
# End redundancy check

# Begin auditd self-rotation
# Rotate the audit logs safely (only auditd can do that)
logger "$0: Asking auditd to rotate its active log file"
/sbin/service auditd rotate
sleep 30
EXITVALUE=$?
if [ $EXITVALUE != 0 ]; then
  /usr/bin/logger -t auditd "ALERT exited abnormally with [$EXITVALUE]"
  exit 0
else
  logger "$0: Auditd reports successful rotation"
fi
# End auditd self-rotation

# Begin rename/compression
# Append date to each rotated audit log, and compress
NEWLOGS=$( ls -1U audit.log.* | grep -E '^audit.log.[0-9][0-9]*$' )
logger "$0: Attempting to rotate the following: $NEWLOGS"
for FILE in $NEWLOGS; do
  SUFFIX=${FILE/audit.log./}
  logger "$0: Renaming audit.log.$SUFFIX to audit.log.$YESTERDAY.$SUFFIX"
  mv audit.log.$SUFFIX audit.log.$YESTERDAY.$SUFFIX
done
for FILE in audit.log.$YESTERDAY.*; do
  logger "$0: Compressing logfile $FILE"
  gzip $FILE
done
logger "$0: Finished"
# End rename/compression

exit 0

