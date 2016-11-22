#!/bin/bash

# Author: Andrew Howard

#TO="user@domain.tld"
TO=""
CC=""
HOSTNAME=$( hostname )
FROM="root@$HOSTNAME"
SUBJECT="Updates available on $HOSTNAME"
MyPrivIP=$( ip route get 8.8.8.8 |
              grep -P '^\s*8.8.8.8\s*via' |
              awk '{print $NF}' )
MyPubIP=$( curl -4 icanhazip.com )


logger "$0 ($$): Starting execution"
LOCK_FILE=/tmp/`basename $0`.lock
function cleanup {
 logger "$0 ($$): Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
logger "$0 ($$): Using lockfile ${LOCK_FILE}"
(set -C; echo "$$" > "${LOCK_FILE}") 2>/dev/null
if [ $? -ne 0 ]; then
 logger "$0 ($$): Lock File exists - exiting"
 exit 1
else
  trap 'cleanup' 1 2 9 15 17 19 23 EXIT
fi

# "yum check-update" returns an exit code of 100 if there are updates available. Handy for shell scripting.
yum check-update -q --disableexcludes=all &>/dev/null; RETVAL=$?

# If no updates available, just log and exit
if [ $RETVAL -eq 0 ]; then
  logger "$0: Checked for updates - none available."
  cleanup
else
  logger "$0: Checked for updates - found some.  Notifying."
fi

OUTPUT=$( yum check-update -q --disableexcludes=all 2>&1 )
sendmail -t -f$FROM <<EOF
To: $TO
Reply-to: $FROM
Cc: $CC
From: $FROM
Subject: $SUBJECT
Results of "yum check-update --disableexcludes=all" on server $HOSTNAME:

$OUTPUT

This message generated by "$0" on $HOSTNAME (PrivateIP:$MyPrivIP, PublicIP:$MyPubIP)
.
EOF


