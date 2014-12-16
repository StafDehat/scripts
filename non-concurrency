#!/bin/bash
# Author: Andrew Howard
# A race-condition-safe bash script wrapper that will ensure this script
# runs non-concurrently with other instances of itself.

logger "$0: Starting execution"

LOCK_FILE=/tmp/`basename $0`.lock
function cleanup {
 logger "$0: Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
trap 'cleanup' 1 2 9 15 17 19 23 EXIT
(set -C; : > $LOCK_FILE) 2> /dev/null
if [ $? != "0" ]; then
 logger "$0: Lock File exists - exiting"
 exit 1
fi
 
######################################
### Place your script content here ###
###################################### 
