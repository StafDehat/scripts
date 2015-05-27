#!/bin/bash
# Author: Andrew Howard

#
# Upload a file to Cloud Files.  If it's over 4GB, split into 1GB chunks.

PIPE1="/tmp/cflf.pipe1"
PIPE2="/tmp/cflf.pipe2"
function cleanup {
 rm -f $PIPE1 $PIPE2
 exit
}
trap 'cleanup' 1 2 9 15 17 19 23 EXIT


function usage() {
  echo "Usage: brc-files-createobject [-h] [-a BRC_AUTHTOKEN] [-v BRC_VAULTNAME] \\"
  echo "                              [-s] [-r BRC_REGION] [-n OBJECTNAME] \\"
  echo "                              [-b BYTES] -f LOCALFILE -c CONTAINER"
  echo "Example:"
  echo "  # brc-files-createobject -a 1a2b3c4d5e6f7g8h9i0j \\"
  echo "                           -v MossoCloudFS_199f2dd2-e293-11e3-87ea-6f46a026e216 \\"
  echo "                           -r dfw \\"
  echo "                           -f /home/user/pbjt.jpg \\"
  echo "                           -c jpegs"
  echo "Arguments:"
  echo "  -a X  Authentication token.  This can be set via the environment"
  echo "        variable BRC_AUTHTOKEN instead of as an argument."
  echo "  -b X  Split object into X-byte sized segments.  Create a manifest file"
  echo "        if this results in multiple segments.  Default:5368709120 (5GB)"
  echo "  -c X  Name of Cloud Files container in which to store file."
  echo "  -f X  Path to local file to be uploaded."
  echo "  -h    Print this help"
  echo "  -n X  Optional.  Filename to use in Cloud Files.  If excluded,"
  echo "        name in Cloud Files will match local filename."
  echo "  -r X  Region.  Examples: iad, dfw, ord, syd.  This can be set via"
  echo "        the environment variable BRC_REGION instead of as an"
  echo "        argument."
  echo "  -s    Use ServiceNet.  For this to work, you must be executing this"
  echo "        command within the same region as BRC_REGION."
  echo "  -v X  Vault name for this account.  This can be set via the environment"
  echo "        variable BRC_VAULTNAME instead of as an argument."
}


USAGEFLAG=0
CONTAINER=""
LOCALFILE=""
OBJECTNAME=""
SNET=0
MAXSIZE=$(( 1024 * 1024 * 1024 * 5 ))
while getopts ":a:b:c:f:hn:r:sv:" arg; do
  case $arg in
    a) BRC_AUTHTOKEN=$OPTARG;;
    b) MAXSIZE=$OPTARG;;
    c) CONTAINER="$OPTARG";;
    f) LOCALFILE="$OPTARG";;
    h) usage && exit 0;;
    n) OBJECTNAME="$OPTARG";;
    r) BRC_REGION=$OPTARG;;
    s) SNET=1;;
    v) BRC_VAULTNAME=$OPTARG;;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))


# Arg testing
for ARG in BRC_AUTHTOKEN BRC_REGION BRC_VAULTNAME; do
  if [ -z "${!ARG}" ]; then
    echo "ERROR: Must define $ARG in environment or argument"
    USAGEFLAG=1
  fi
done
for ARG in CONTAINER LOCALFILE; do
  if [ -z "${!ARG}" ]; then
    echo "ERROR: Must define $ARG as argument"
    USAGEFLAG=1
  fi
done
if [ $USAGEFLAG -ne 0 ]; then
  usage && exit 1
fi
if [ ! -f "$LOCALFILE" ]; then
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

# These are the variables you'll need to set
LOCALFILE=/home/rack/image.vhd
FILES_VAULT=MossoCloudFS_3ce9abd8-cbc7-11e3-9eee-27700cf6687a
FILES_ENDPOINT=https://storage101.dfw1.clouddrive.com/v1
CONTAINER=MyContainer
CFNAME=MyBigFile


function uploadSmallFile() {
  local FILE="$1"
  local CFNAME="$2"
  # BUG: http://curl.haxx.se/changes.html
  #      "Fixed in 7.37.0 - May 21 2014"
  #      "sockfilt.c: properly handle disk files, pipes and character input"
  #      Because of this, I can't pass the file directly to curl - gotta
  #      cat it and pipe to curl, then use "-T -" to read from stdin with curl.
  DATA=$( cat "$FILE" | curl -I --write-out \\n%{http_code} --silent --output - \
               $FILES_ENDPOINT/$BRC_VAULTNAME/"$CONTAINER"/"$CFNAME" \
               -X PUT \
               -T - \
               -H "X-Auth-Token: $BRC_AUTHTOKEN" \
            2>/dev/null )
  RETVAL=$?
  CODE=$( echo "$DATA" | tail -n 1 )
  # Check for failed API call
  if [ $RETVAL -ne 0 ]; then
    errorcurlfail
  elif ! grep -qE '^2..$' <<<$CODE; then
    errornot200 $CODE $( echo "$DATA" | head -n -1 )
  fi
  # Print the md5sum etag
  # We'll test the value outside this function
  # Trying to test inside this function puts us in named-pipe hell, introduces deadlock,
  #   and/or forces us to run the 'dd' twice.
  echo "$DATA" | sed -n 's/^\s*Etag:\s*//p'
}


function uploadLargeFile() {
  local FILE="$1"
  local CFNAME="$2"
  local SIZE=$( stat -c %s "$FILE" )
  local SEGMENTS=$(( $SIZE / $MAXSIZE ))
  if [ $(( $SIZE % $MAXSIZE )) -eq 0 ]; then
    SEGMENTS=$(( $SEGMENTS - 1 ))
  fi

  # Upload all the file segments, $MAXSIZE bytes at a time
  mkfifo $PIPE1 $PIPE2
  for COUNT in $( seq -w 0 $SEGMENTS ); do
    # Retry loop - try 10 times
    for x in `seq 1 10`; do
      echo "Creating object '${CFNAME}-$COUNT'."
      RSIZE=$(($MAXSIZE/4096))
      # bs=4096 -- Attempt to optimize read speeds by matching block size on drive architecture
      # count=$RSIZE -- Read $MAXSIZE bytes
      # skip=$RSIZE * $COUNT -- Skip previously-read $MAXSIZE chunks
      dd if="$FILE" bs=4k count=$RSIZE skip=$(( $RSIZE * $((10#$COUNT)) )) 2>/dev/null \
        | tee $PIPE1 \
        | md5sum | awk '{print $1}' > $PIPE2 &
      local ETAG=$( uploadSmallFile $PIPE1 \
                                    "${CFNAME}"-$COUNT )
      MD5=$( cat $PIPE2 )
      # If segment uploaded successfully, break the x(1-10) retry loop
      # Stay in the COUNT loop.  ie: Do the next segment.
      if grep -q "$MD5" <<<$ETAG; then
        break
      fi
      # MD5 error - loop to retry
      continue
    done #End for x(1-10)
  done #End for COUNT
  rm -f $PIPE1 $PIPE2

  # Create a dynamic manifest file
  echo "Creating manifest object '$CFNAME'."
  DATA=$( curl --write-out \\n%{http_code} --silent --output - \
               $FILES_ENDPOINT/$BRC_VAULTNAME/"$CONTAINER"/"$CFNAME" \
               -T /dev/null \
               -X PUT \
               -H "X-Auth-Token: $BRC_AUTHTOKEN" \
               -H "X-Object-Manifest: $CONTAINER/${CFNAME}-" \
            2>/dev/null )
  RETVAL=$?
  CODE=$( echo "$DATA" | tail -n 1 )
  # Check for failed API call
  if [ $RETVAL -ne 0 ]; then
    errorcurlfail
  elif ! grep -qE '^2..$' <<<$CODE; then
    errornot200 $CODE $( echo "$DATA" | head -n -1 )
  fi
}


#
# Test the source file.
# If > 5G then upload in 1G segments, then create a dynamic manifest
# http://docs.rackspace.com/files/api/v1/cf-devguide/content/Large_Object_Creation-d1e2019.html
if [ $( stat -c %s "$LOCALFILE" ) -le $MAXSIZE ]; then
  # Retry loop - try <=10 times
  for x in `seq 1 10`; do
    echo "Creating object '$OBJECTNAME'."
    MD5=$( md5sum "$LOCALFILE" | awk '{print $1}' )
    ETAG=$( uploadSmallFile $LOCALFILE "$OBJECTNAME" )
    # If segment uploaded successfully, break the x(1-10) retry loop
    if grep -q "$MD5" <<<$ETAG; then
      break
    fi
    # MD5 error - loop to retry
    echo "Checksum error - retrying"
    continue
  done
else
  echo "Object '$OBJECTNAME' >$MAXSIZE bytes.  Splitting into segments."
  uploadLargeFile "$LOCALFILE" "$OBJECTNAME"
fi

exit 0

