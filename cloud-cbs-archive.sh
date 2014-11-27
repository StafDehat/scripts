#!/bin/bash
#
# Author: Andrew Howard
#
# Archive a block device into 

#
# Remove any stuff we created
function cleanup() {
  echo "----------------------------------------"
  echo "Script exited prematurely."
  echo "----------------------------------------"
  exit 1
}
trap 'cleanup' 1 2 9 15 17 19 23


#
# Usage statement
function usage() {
  echo "Usage: cloud-cbs-archive.sh [-h] [-s] [-f] \\"
  echo "                            -b BLOCKDEVICE \\"
  echo "                            -u APIUSERNAME \\"
  echo "                            -r REGION \\"
  echo "                            [-a APIKEY]"
  echo "Example:"
  echo "  # cloud-cbs-archive.sh -s \\"
  echo "                         -t rackcloud \\"
  echo "                         -b /dev/xvdb \\"
  echo "                         -r dfw"
  echo "Arguments:"
  echo "  -a X  API Key (not token)."
  echo "  -b X  Block device to archive."
  echo "  -f    Force, even if device is mounted."
  echo "  -h    Print this help."
  echo "  -r X  Region for Cloud Files storage (DFW/ORD/IAD/etc)."
  echo "  -s    Use ServiceNet for upload."
  echo "  -u X  API Username."
}


#
# Hard-coded variabled
IDENTITY_ENDPOINT="https://identity.api.rackspacecloud.com/v2.0"
DATE=$( date +"%F_%H-%M-%S" )


#
# Verify the existence of pre-req's
PREREQS="curl grep sed date cut tr echo column nc"
PREREQFLAG=0
for PREREQ in $PREREQS; do
  which $PREREQ &>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Gotta have '$PREREQ' binary to run."
    PREREQFLAG=1
  fi
done
if [ $PREREQFLAG -ne 0 ]; then
  exit 1
fi


#
# 
SNET=0
FORCE=0
USAGEFLAG=0
while getopts ":a:b:fhr:su:" arg; do
  case $arg in
    a) APIKEY="$OPTARG";;
    b) BLOCKDEVICE="$OPTARG";;
    f) FORCE=1;;
    h) usage && exit 0;;
    r) REGION="$OPTARG";;
    s) SNET=1;;
    u) APIUSER="$OPTARG";;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))

for ARG in REGION BLOCKDEVICE APIUSER; do
  if [ -z "${!ARG}" ]; then
    echo "ERROR: Must define $ARG as argument"
    USAGEFLAG=1
  fi
done
if [ $USAGEFLAG -ne 0 ]; then
  usage && exit 1
fi
if [ ! -e "$BLOCKDEVICE" ]; then
  echo "ERROR: Can not access $LOCALFILE - does it exist?"
  exit 1
fi


if [ "$SNET" -eq 1 ]; then
  FILES_ENDPOINT=$( $BRCUTIL/brc-util-filesendpoint -r $BRC_REGION -i )
else
  FILES_ENDPOINT=$( $BRCUTIL/brc-util-filesendpoint -r $BRC_REGION )
fi
FILESHOST=$( echo "$FILES_ENDPOINT" | cut -d/ -f3 )
nc -w 5 -z $FILESHOST 443 &>/dev/null
if [ $? -ne 0 ]; then
  echo "Error: Unable to reach Cloud Files API ($FILESHOST:443)."
  exit 1
fi

if [ -z "$OBJECTNAME" ]; then
  OBJECTNAME=$( basename "$LOCALFILE" )
fi






