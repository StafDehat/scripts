#!/bin/bash
# Author: Andrew Howard

#
# Upload a file to Cloud Files.
# If it's over the max size (-b MAXSIZE-BYTES), split into multiple
#   segments and create a manifest file.
#
# Here's an example:
# ahoward@phoenix[~]$ dd if=/dev/urandom of=tmpfile bs=4096 count=2560
# 2560+0 records in
# 2560+0 records out
# 10485760 bytes (10 MB) copied, 1.07393 s, 9.8 MB/s
# ahoward@phoenix[~]$ ll -h tmpfile
# -rw-rw-r-- 1 ahoward ahoward 10M May 27 09:48 tmpfile
# ahoward@phoenix[~]$ OneMeg=$((1024*1024))
# ahoward@phoenix[~]$ cloud-files-createobject.sh -r dfw -c andr4596 -f tmpfile -b $OneMeg
# Enter cloud account username: 
# Enter cloud account API Key: 
# Object 'tmpfile' >1048576 bytes.  Splitting into segments.
# Creating object 'tmpfile-0'.
# Creating object 'tmpfile-1'.
# Creating object 'tmpfile-2'.
# Creating object 'tmpfile-3'.
# Creating object 'tmpfile-4'.
# Creating object 'tmpfile-5'.
# Creating object 'tmpfile-6'.
# Creating object 'tmpfile-7'.
# Creating object 'tmpfile-8'.
# Creating object 'tmpfile-9'.
# Creating manifest object 'tmpfile'.
# ahoward@phoenix[~]$ 


PREREQS="curl grep sed cut tr echo dd"
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


TMPDIR=$( mktemp -d )
PIPE1="$TMPDIR/pipe1"
PIPE2="$TMPDIR/pipe2"
function cleanup {
  rm -f $PIPE1 $PIPE2
  if [ -d $TMPDIR ]; then
    rmdir $TMPDIR
  fi
  stty echo
  exit
}
trap 'cleanup' 1 2 9 15 17 19 23 EXIT


function usage() {
  echo "Usage: cloud-files-upload.sh [-h] [-u USERNAME] [-k APIKEY] \\"
  echo "                             [-s] [-b BYTES] [-n OBJECTNAME] \\"
  echo "                             -r REGION -f LOCALFILE -c CONTAINER"
  echo "Example:"
  echo "  # cloud-files-upload.sh -r dfw \\"
  echo "                          -f /home/user/pbjt.jpg \\"
  echo "                          -c jpegs"
  echo "Arguments:"
  echo "  -b X  Limit individual object size to X bytes.  Create a manifest file"
  echo "        if this results in multiple segments.  Default: 1073741824 (1GB)"
  echo "  -c X  Name of Cloud Files container in which to store file."
  echo "  -f X  Path to local file to be uploaded."
  echo "  -h    Print this help"
  echo "  -k X  Optional.  Cloud account's API key.  If omitted from arguments"
  echo "        then it must be provided interactively via prompts."
  echo "  -n X  Optional.  Filename to use in Cloud Files.  If omitted,"
  echo "        name in Cloud Files will match local filename."
  echo "  -r X  Cloud region.  Examples: iad, dfw, ord, syd."
  echo "  -s    Use ServiceNet."
  echo "  -u X  Optional.  Cloud account username.  If omitted from arguments"
  echo "        then it must be provided interactively via prompts."
}

function getApiToken() {
  local tokenData="${1}"
  if which jq &>/dev/null; then
    jq -r ".access.token.id" <<<"${tokenData}"
  elif  which perl &>/dev/null; then
    echo "${tokenData}" | perl -pe 's/.*"token":.*?"id":"(.*?)".*$/\1/'
  else
    # Pretty sure this method is broken:
    echo "${tokenData}" | 
      tr ',' '\n' |
      sed -n '/token/,/APIKEY/p' |
      sed -n '/token/,/}/p' |
      grep -v \"id\":\"$TENANTID\" |
      sed -n 's/.*"id":"\([^"]*\)".*/\1/p'
  fi
}

function getTenantId() {
  local tokenData="${1}"
  if which jq &>/dev/null; then
    jq -r ".access.token.tenant.id" <<<"${tokenData}"
  elif which perl &>/dev/null; then
    echo "${tokenData}" | perl -pe 's/.*"token":.*?"tenant":.*?"id":"(.*?)".*$/\1/'
  else
    # Pretty sure this method is broken:
    echo "${tokenData}" |
      tr ',' '\n' |
      sed -n '/token/,/APIKEY/p' |
      sed -n '/tenant/,/}/p' |
      sed -n 's/.*"id":"\([^"]*\)".*/\1/p'
  fi
}

function getVaultName() {
  local REGION="${1}"
  local tokenData="${2}"
  if which jq &>/dev/null; then
    local numKeys
    local keyName
    local keyType
    local keyRegion
    local filesIndex
    local regionIndex
    # Identify list item with:
    # "name": "cloudFiles",
    # "type": "object-store"
    numKeys=$( jq -r ".access.serviceCatalog|length" <<<"${tokenData}" )
    for x in $( seq 0 ${numKeys} ); do
      keyName=$( jq -r ".access.serviceCatalog[${x}].name" <<<"${tokenData}" )
      keyType=$( jq -r ".access.serviceCatalog[${x}].type" <<<"${tokenData}" )
      if [[ "${keyName}" == "cloudFiles" ]] ||
         [[ "${keyType}" == "object-store" ]]; then
        filesIndex="${x}"
        break # Short-circuit
      fi
    done
    # Found Cloud Files index.  Now find the index of the right Region.
    numKeys=$( jq ".access.serviceCatalog[${filesIndex}].endpoints|length" <<<"${tokenData}" )
    for x in $( seq 0 ${numKeys} ); do
      keyRegion=$( jq -r ".access.serviceCatalog[${filesIndex}].endpoints[${x}].region" <<<"${tokenData}" |
                     tr 'A-Z' 'a-z' )
      if [[ "${keyRegion}" == "${REGION}" ]]; then
        regionIndex="${x}"
        break # Short-circuit
      fi
    done
    # Found the right Region.  Now grab its Vault name.
    basename $( jq -r ".access.serviceCatalog[${filesIndex}].endpoints[${regionIndex}].publicURL" <<<"${tokenData}" )
  elif which perl &>/dev/null; then
    # Broken.  TODO item.
    echo "Fail"
  else
    # Broken.  TODO item.
    echo "${tokenData}" |
      sed 's/endpoints/\n/g' | 
      grep cloudFiles | grep tenantId | grep MossoCloudFS_ |
      tr '{},' '\n' | 
      grep tenantId | sort -u | head -n 1 | 
      cut -d\" -f4
  fi
}


USAGEFLAG=0
USERNAME=""
APIKEY=""
CONTAINER=""
LOCALFILE=""
OBJECTNAME=""
REGION=""
SNET=0
MAXSIZE=$(( 1024 * 1024 * 1024 ))
#MAXSIZE=$(( 1024 * 1024 * 256 ))
COMPRESS="no"
while getopts ":b:c:f:hk:n:r:su:z" arg; do
  case $arg in
    b) MAXSIZE="$OPTARG";;
    c) CONTAINER="$OPTARG";;
    f) LOCALFILE="$OPTARG";;
    h) usage && exit 0;;
    k) APIKEY="$OPTARG";;
    n) OBJECTNAME="$OPTARG";;
    r) REGION="$OPTARG";;
    s) SNET=1;;
    u) USERNAME="$OPTARG";;
    z) COMPRESS="yes";;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))

for ARG in REGION LOCALFILE CONTAINER; do
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
if [ -z "$USERNAME" ]; then
  read -p "Enter cloud account username: " -s USERNAME
  echo
fi
if [ -z "$APIKEY" ]; then
  read -p "Enter cloud account API Key: " -s APIKEY
  echo
fi
if [ -z "$OBJECTNAME" ]; then
  OBJECTNAME=$( basename "$LOCALFILE" )
fi

IDENTITY_ENDPOINT="https://identity.api.rackspacecloud.com/v2.0"

FILES_ENDPOINT=""
if [ $SNET -eq 1 ]; then
  FILES_ENDPOINT="https://snet-"
else 
  FILES_ENDPOINT="https://"
fi
REGION=$( tr 'A-Z' 'a-z' <<<"$REGION" )
case $REGION in
  ord) FILES_ENDPOINT="${FILES_ENDPOINT}storage101.ord1.clouddrive.com/v1";;
  dfw) FILES_ENDPOINT="${FILES_ENDPOINT}storage101.dfw1.clouddrive.com/v1";;
  hkg) FILES_ENDPOINT="${FILES_ENDPOINT}storage101.hkg1.clouddrive.com/v1";;
  lon) FILES_ENDPOINT="${FILES_ENDPOINT}storage101.lon3.clouddrive.com/v1";;
  iad) FILES_ENDPOINT="${FILES_ENDPOINT}storage101.iad3.clouddrive.com/v1";;
  syd) FILES_ENDPOINT="${FILES_ENDPOINT}storage101.syd2.clouddrive.com/v1";;
    *) echo "ERROR: Unrecognized REGION code." && exit 1;;
esac
FILESHOST=$( echo "$FILES_ENDPOINT" | cut -d/ -f3 )
if ! ( echo > /dev/tcp/$FILESHOST/443 ) &>/dev/null; then
  echo "Error: Unable to reach Cloud Files API ($FILESHOST:443)."
  exit 1
fi


#
# Auth against API
DATA=$(curl --write-out \\n%{http_code} --silent --output - \
            $IDENTITY_ENDPOINT/tokens \
            -H "Content-Type: application/json" \
            -d '{ "auth": {
                    "RAX-KSKEY:apiKeyCredentials": {
                      "apiKey": "'"$APIKEY"'",
                      "username": "'"$USERNAME"'" } } }' \
         2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif grep -qvE '^2..$' <<<$CODE; then
  echo "Error: Unable to authenticate against API using USERNAME and APIKEY"
  echo "  provided.  Raw response data from API was the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && exit 1
fi
unset USERNAME
unset APIKEY
APITOKEN=$( echo "$DATA" | sed '$d' )
TENANTID=$( getTenantId "${APITOKEN}" )
AUTHTOKEN=$( getApiToken "${APITOKEN}" )
VAULTNAME=$( getVaultName "${REGION}" "${APITOKEN}" )
echo
echo "Authentication info:"
echo "Tenant ID: $TENANTID"
echo "TokenData: $AUTHTOKEN"
echo "VaultName: $VAULTNAME"
echo

function uploadSmallFile() {
  local FILE="$1"
  local CFNAME="$2"
  # BUG: http://curl.haxx.se/changes.html
  #      "Fixed in 7.37.0 - May 21 2014"
  #      "sockfilt.c: properly handle disk files, pipes and character input"
  #      Because of this, I can't pass the file directly to curl - gotta
  #      cat it and pipe to curl, then use "-T -" to read from stdin with curl.
  DATA=$( cat "$FILE" | curl -I --write-out \\n%{http_code} --silent --output - \
               "$FILES_ENDPOINT"/"$VAULTNAME"/"$CONTAINER"/"$CFNAME" \
               -X PUT \
               -T - \
               -H "X-Auth-Token: $AUTHTOKEN" \
            2>/dev/null )
  RETVAL=$?
  CODE=$( echo "$DATA" | tail -n 1 )
  echo "Response:"
  echo "$CODE"
  echo "$DATA"
  # Check for failed API call
  if [ $RETVAL -ne 0 ]; then
    echo "Unknown error while attempting to run curl command"
    exit 1
  elif ! grep -qE '^2..$' <<<$CODE; then
    echo "ERROR: curl command did not receive HTTP 200 response"
    exit 1
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
      # Else MD5 error - loop to retry
      echo "MD5 mismatch - retrying upload."
      continue
    done #End for x(1-10)
  done #End for COUNT
  rm -f $PIPE1 $PIPE2
  rmdir $TMPDIR

  # Create a dynamic manifest file
  # To-Do: Change this to a static manifest file
  echo "Creating manifest object '$CFNAME'."
  DATA=$( curl --write-out \\n%{http_code} --silent --output - \
               $FILES_ENDPOINT/$VAULTNAME/"$CONTAINER"/"$CFNAME" \
               -T /dev/null \
               -X PUT \
               -H "X-Auth-Token: $AUTHTOKEN" \
               -H "X-Object-Manifest: $CONTAINER/${CFNAME}-" \
            2>/dev/null )
  RETVAL=$?
  CODE=$( echo "$DATA" | tail -n 1 )
  # Check for failed API call
  if [ $RETVAL -ne 0 ]; then
    echo "Unknown error while attempting to run curl command"
    exit 1
  elif ! grep -qE '^2..$' <<<$CODE; then
    echo "ERROR: curl command did not receive HTTP 200 response"
    exit 1
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

