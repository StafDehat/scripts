#!/bin/bash
#
# Author: Andrew Howard
# This script will copy an image from one region to another.
# BE AWARE: This will incur charges for the customer.  These charges
# can be minimized by using ServiceNet for the download and by choosing
# to auto-delete the Cloud Files content once the transfer is complete.
# Even with these precautions, the customer will be charged for storage
# fees in Cloud Files (for a single month) and Cloud Images (destination).
# Note: To use ServiceNet, this script MUST be run on a Cloud Server
# in the same region as the source image.

# Note: The export/import process breaks Managed SLA on the image and
# all servers built from the image.

# To-do:
# Detect authtoken expiration and prompt for new token
# Batch-mode & interactive mode
# Test images with >100 segments
#   >Or confirm impossible.  Imports limited to 40G, so...
# Test secondary auth

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
# Set some status variables
# This will help report what needs to be cleaned up,
#   in the case that this script exits uncleanly.
GOODCREDS=0
MADESRCCONT=0
MADEDSTCONT=0
EXPORTED=0
IMPORTED=0
SAVELOCAL=0


#
# Define a clean-up function and catch exit signals
function cleanup {
  stty echo
  echo "----------------------------------------"
  echo "Script exited prematurely."
  echo "You may need to manually delete the following:"
  if [ $MADESRCCONT -ne 0 ]; then
    echo "Container $CONTAINER in Cloud Files region $SRCRGN on account $SRCTENANTID"
  fi
  if [ $MADEDSTCONT -ne 0 ]; then
    echo "Container $CONTAINER in Cloud Files region $DSTRGN on account $DSTTENANTID"
  fi
  if [ $EXPORTED -ne 0 ]; then
    echo "Export task $SRCTASKID in region $SRCRGN on account $SRCTENANTID"
  fi
  if [ $IMPORTED -ne 0 ]; then
    echo "Import task $DSTTASKID in region $DSTRGN on account $DSTTENANTID"
  fi
  if [ $SAVELOCAL -ne 0 ]; then
    echo "Folder and contents on local storage: /tmp/$CONTAINER"
  fi
  echo "----------------------------------------"
  exit 1
}
trap 'cleanup' 1 2 9 15 19 23
trap 'cleanup' 1 2 9 15 19 23


#
# Usage statement
function usage() {
  echo "Note: Authentication has changed!"
  echo "      This script used to use Tenant ID and API Token."
  echo "      Now it uses Username and API Key."
  echo
  echo "Usage: cloud-image-region-transfer.sh [-h] [-s] [-1] \\"
  echo "                                      -i SRCIMGID \\"
  echo "                                      -u SRCUSERNAME  -U DSTUSERNAME \\"
  echo "                                      -r SRCRGN       -R DSTRGN \\"
  echo "                                      [-a SRCAPIKEY]  [-A DSTAPIKEY]"
  echo "Example:"
  echo "  # cloud-image-region-transfer.sh -u rackuser1 \\"
  echo "                                   -r dfw \\"
  echo "                                   -R iad \\"
  echo "                                   -i 8883bb30-cd7d-11e3-ab61-3b672f712d5f \\"
  echo "                                   -1 -s"
  echo "Example:"
  echo "  # cloud-image-region-transfer.sh -u rackuser1 \\"
  echo "                                   -U rackuser2 \\"
  echo "                                   -r dfw \\"
  echo "                                   -R iad \\"
  echo "                                   -i 8883bb30-cd7d-11e3-ab61-3b672f712d5f"
  echo "Arguments:"
  echo "Note: Source args in lowercase, destination in uppercase."
  echo "  -1    Use the source account details for the destination too"
  echo "        (overrides -A and -T)."
  echo "  -a X  API Key (not token) of source account."
  echo "        Optional - If not provided, will prompt for input."
  echo "  -A X  API Key (not token) of destination account."
  echo "        Optional - If not provided, will prompt for input."
  echo "  -h    Print this help"
  echo "  -i X  Image ID.  Find in MyCloud by hovering over image name."
  echo "  -r X  Region of source (DFW/ORD/IAD/etc)"
  echo "  -R X  Region of destination (DFW/ORD/IAD/etc)."
  echo "  -s    Use ServiceNet for download (Must run this script in same"
  echo "        region as defined for SRCRGN)."
  echo "  -u X  Username of source account."
  echo "  -U X  Username of destination account."
}


#
# Run a curl command
# Store response code & data in variables named in $2 and $3 respectively
# If 401 received and creds are known good, re-authenticate and retry
function doCurl() {
  # $@ = the curl command
  while true; do
    DATA=$( eval curl --write-out \"\\n\"%{http_code} --silent --output - $@ )
    RETVAL=$?
    CODE=$( echo "$DATA" | tail -n 1 )
    DATA=$( echo "$DATA" | sed '$d' )
    if [ $RETVAL -ne 0 ]; then
      echo "Unknown error encountered when trying to run curl command."
      cleanup
    elif grep -qE '^401$' <<<$CODE; then
      if [ $GOODCREDS -eq 1 ]; then
        echo "Received 401, but we know the provided credentials are correct."
        echo "  API token must have expired - attempting to re-auth."
        echo "If the API key has changed, this is going to loop forever."
        setAuthTokens
      else
        echo "ERROR: Unable to authenticate with credentials provided."
        echo "  API response was as follows:"
        echo
        echo "Response code: $CODE"
        echo "$DATA" && cleanup
      fi
    else
      # Curl ran successfully and did not receive code 401.
      break
    fi
    # Just in case we loop infinitely, let's not DoS the API nodes
    sleep 5
  done
}


#
# Auth against API and export token data to global variables
# Yes, I know.  I don't care.  I'm using globals.  Deal.
function setAuthTokens() {
  #
  # Auth against API, both to confirm DDI/Token, and to get
  #   endpoints & Cloud Files Vault ID
  echo "Attempting to authenticate against Identity API with source account info."
  doCurl $( cat <<EOF
    $IDENTITY_ENDPOINT/tokens \
    -H "Content-Type: application/json" \
    -d '{ "auth": {
            "RAX-KSKEY:apiKeyCredentials": {
              "apiKey": "$SRCAPIKEY",
              "username": "$SRCUSERNAME" } } }'
EOF
)
  if grep -qvE '^2..$' <<<$CODE; then
    echo "Error: API response != 2**.  Not sure why."
    echo "  Response from API was as follows:"
    echo
    echo "Response code: $CODE"
    echo "$DATA" && cleanup
  fi
  echo "Successfully authenticated using provided SRCUSERNAME and SRCAPIKEY."
  echo
  SRCTOKEN="$DATA"
  # Fuck JSON.  Seriously.
  SRCTENANTID=$( echo "$SRCTOKEN" | 
                   tr ',' '\n' | 
                   sed -n '/token/,/APIKEY/p' | 
                   sed -n '/tenant/,/}/p' | 
                   sed -n 's/.*"id":"\([^"]*\)".*/\1/p' )
  SRCAUTHTOKEN=$( echo "$SRCTOKEN" | 
                    tr ',' '\n' | 
                    sed -n '/token/,/APIKEY/p' | 
                    sed -n '/token/,/}/p' | 
                    grep -v \"id\":\"$SRCTENANTID\" | 
                    sed -n 's/.*"id":"\([^"]*\)".*/\1/p' )
  #
  # Authentication destination creds, unless "-1" was passed
  if [ $ONEACCOUNT -eq 1 ]; then
    echo "Single account - Copying SRC creds to DST creds."
    echo
    DSTTENANTID=$SRCTENANTID
    DSTAUTHTOKEN=$SRCAUTHTOKEN
    return
  fi
  echo "Attempting to authenticate against Identity API with destination account info."
  doCurl $( cat <<EOF
    $IDENTITY_ENDPOINT/tokens \
    -H "Content-Type: application/json" \
    -d '{ "auth": {
            "RAX-KSKEY:apiKeyCredentials": {
              "apiKey": "$DSTAPIKEY",
              "username": "$DSTUSERNAME" } } }'
EOF
)
  if grep -qvE '^2..$' <<<$CODE; then
    echo "Error: API response != 2**.  Not sure why."
    echo "  Response from API was as follows:"
    echo
    echo "Response code: $CODE"
    echo "$DATA" && cleanup
  fi
  echo "Successfully authenticated using provided DSTUSERNAME and DSTAPIKEY."
  echo
  DSTTOKEN="$DATA"
  DSTTENANTID=$( echo "$DSTTOKEN" | 
                   tr ',' '\n' | 
                   sed -n '/token/,/APIKEY/p' | 
                   sed -n '/tenant/,/}/p' | 
                   sed -n 's/.*"id":"\([^"]*\)".*/\1/p' )
  DSTAUTHTOKEN=$( echo "$DSTTOKEN" | 
                    tr ',' '\n' | 
                    sed -n '/token/,/APIKEY/p' | 
                    sed -n '/token/,/}/p' | 
                    grep -v \"id\":\"$DSTTENANTID\" | 
                    sed -n 's/.*"id":"\([^"]*\)".*/\1/p' )


}


#
# Confirm usage is correct, and all variables passed
USAGEFLAG=0
SNET=0
ONEACCOUNT=0
while getopts ":1a:A:hi:r:R:su:U:" arg; do
  case $arg in
    1) ONEACCOUNT=1;;
    a) SRCAPIKEY=$OPTARG;;
    A) DSTAPIKEY=$OPTARG;;
    h) usage && exit 0;;
    i) SRCIMGID=$OPTARG;;
    r) SRCRGN=$OPTARG;;
    R) DSTRGN=$OPTARG;;
    s) SNET=1;;
    u) SRCUSERNAME=$OPTARG;;
    U) DSTUSERNAME=$OPTARG;;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))
if [ "$ONEACCOUNT" -eq 1 ]; then
  DSTUSERNAME="$SRCUSERNAME"
fi
ARGUMENTS="SRCUSERNAME DSTUSERNAME SRCRGN DSTRGN SRCIMGID"
for ARGUMENT in $ARGUMENTS; do
  if [ -z "${!ARGUMENT}" ]; then
    echo "ERROR: Must define $ARGUMENT as argument."
    USAGEFLAG=1
  fi
done
if [ $USAGEFLAG -ne 0 ]; then
  usage && exit 1
fi
if [ -z "$SRCAPIKEY" ]; then
  read -p "Enter source account's API Key: " -s SRCAPIKEY
  echo
  if [ "$ONEACCOUNT" -eq 1 ]; then
    DSTAPIKEY="$SRCAPIKEY"
  else
    read -p "Enter destination account's API Key: " -s DSTAPIKEY
    echo
  fi
fi


#
# Put regions in lowercase.
SRCRGN=$( echo $SRCRGN | tr 'A-Z' 'a-z' )
DSTRGN=$( echo $DSTRGN | tr 'A-Z' 'a-z' )


#
# Auth against API, both to confirm DDI/Token, and to get
#   endpoints & Cloud Files Vault ID
setAuthTokens


#
# Keep internal record that the creds passed to the script are valid.
#   This means future auth failures are due to API Token rotation,
#   not due to user error.
GOODCREDS=1


#
# Find the Images endpoints
echo "Attempting to identify Image API endpoints."
if [ "$SRCRGN" == "lon" ]; then
  SRCIMGURL="https://lon.images.api.rackspacecloud.com/v2/$SRCTENANTID"
else
  SRCIMGURL=$( echo "$SRCTOKEN" | tr '"' '\n' | grep "$SRCRGN.images.api.rackspacecloud.com" | tr -d '\\' )
fi
if [ "$DSTRGN" == "lon" ]; then
  DSTIMGURL="https://lon.images.api.rackspacecloud.com/v2/$DSTTENANTID"
else
  DSTIMGURL=$( echo "$DSTTOKEN" | tr '"' '\n' | grep "$DSTRGN.images.api.rackspacecloud.com" | tr -d '\\' )
fi
echo "Identified Images API endpoints:"
echo "Source:      $SRCIMGURL"
echo "Destination: $DSTIMGURL"
echo 


#
# Verify SRCIMGID exists in SRCRGN
echo "Verifying image exists."
  doCurl $( cat <<EOF
             $SRCIMGURL/images/$SRCIMGID \
             -X GET \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $SRCAUTHTOKEN" \
             -H "X-Auth-Project-Id: $SRCTENANTID" \
             -H "X-Tenant-Id: $SRCTENANTID" \
             -H "X-User-Id: $SRCTENANTID"
EOF
)
if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to get details of source image - does it exist?  Did"
  echo "  you specify the correct SRCRGN?  Raw response data from API was"
  echo "  the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
echo "Image successfully located in region '$SRCRGN' on account $SRCTENANTID."
# Check if image is sufficient size
MINDISK=$( echo "$DATA" | tr ',' '\n' | grep '"min_disk":' | awk '{print $NF}' )
if [ $MINDISK -gt 40 ]; then
  echo "Error: You won't be able to import this image at the destination,"
  echo "  because it was taken of a server with >40G OS disk.  You'll need"
  echo "  to build a Standard NextGen server from this image at the source"
  echo "  region, resize it to <=2G RAM (<=40G disk), then take a new image"
  echo "  and transfer that new image instead."
  echo 
  echo "Ref:"
  echo "http://www.rackspace.com/knowledge_center/article/preparing-an-image-for-import-into-the-rackspace-open-cloud"
  exit 1
else
  echo "Confirmed image has min_disk <= 40GB."
fi
IMGNAME=$( echo "$DATA" | tr ',' '\n' | grep '"name":' | cut -d'"' -f4 )
echo "Image name: $IMGNAME"
echo


#
# Determine the Cloud Files endpoints
# I am, unfortunately, forced to hard-code these URLs since the TOKEN
#   does not include Cloud Files URLs - only the Vault ID.
SRCVAULTID=$( echo "$SRCTOKEN" | tr '"' '\n' | awk '/^MossoCloudFS_/ {print}' | head -n 1 )
DSTVAULTID=$( echo "$DSTTOKEN" | tr '"' '\n' | awk '/^MossoCloudFS_/ {print}' | head -n 1 )
if [ "$SNET" -eq 1 ]; then
  SRCFILEURL="https://snet-"
else 
  SRCFILEURL="https://"
fi
case $SRCRGN in
  ord) SRCFILEURL="${SRCFILEURL}storage101.ord1.clouddrive.com/v1/$SRCVAULTID";;
  dfw) SRCFILEURL="${SRCFILEURL}storage101.dfw1.clouddrive.com/v1/$SRCVAULTID";;
  hkg) SRCFILEURL="${SRCFILEURL}storage101.hkg1.clouddrive.com/v1/$SRCVAULTID";;
  lon) SRCFILEURL="${SRCFILEURL}storage101.lon3.clouddrive.com/v1/$SRCVAULTID";;
  iad) SRCFILEURL="${SRCFILEURL}storage101.iad3.clouddrive.com/v1/$SRCVAULTID";;
  syd) SRCFILEURL="${SRCFILEURL}storage101.syd2.clouddrive.com/v1/$SRCVAULTID";;
    *) echo "ERROR: Unrecognized REGION code." && cleanup;;
esac
case $DSTRGN in
  ord) DSTFILEURL="https://storage101.ord1.clouddrive.com/v1/$DSTVAULTID";;
  dfw) DSTFILEURL="https://storage101.dfw1.clouddrive.com/v1/$DSTVAULTID";;
  hkg) DSTFILEURL="https://storage101.hkg1.clouddrive.com/v1/$DSTVAULTID";;
  lon) DSTFILEURL="https://storage101.lon3.clouddrive.com/v1/$DSTVAULTID";;
  iad) DSTFILEURL="https://storage101.iad3.clouddrive.com/v1/$DSTVAULTID";;
  syd) DSTFILEURL="https://storage101.syd2.clouddrive.com/v1/$DSTVAULTID";;
    *) echo "ERROR: Unrecognized REGION code." && cleanup;;
esac


#
# Confirm connectivity to servicenet, if necessary
if [ $SNET -eq 1 ]; then
  SNETHOST=$( echo "$SRCFILEURL" | cut -d/ -f3 )
  echo "Testing connectivity to $SNETHOST on tcp/443."
  nc -w 5 -z $SNETHOST 443 &>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Unable to reach Cloud Files API over ServiceNet."
    echo "You may have to use public traffic instead."
    exit 1
  fi
  echo "Connection to ServiceNet successful."
  echo
fi


#
# Create a container in which to save the exported image
CONTAINER="img-copy-$DATE"
echo "Creating Cloud Files container ($CONTAINER) on account $SRCTENANTID to house exported image."
  doCurl $( cat <<EOF
             $SRCFILEURL/$CONTAINER \
             -X PUT \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $SRCAUTHTOKEN"
EOF
)
if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to create container '$CONTAINER' in region '$SRCRGN'"
  echo "  on account $SRCTENANTID."
  echo "  Does it already exist?  Raw response data from API is as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
MADESRCCONT=1
echo "Successully created container in region '$SRCRGN' on account $SRCTENANTID."
echo


#
# Confirm the existence of Source Cloud Files container
echo "Attempting to confirm Cloud Files container does now exist."
  doCurl $( cat <<EOF
             $SRCFILEURL/$CONTAINER \
             -X GET \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $SRCAUTHTOKEN"
EOF
)
if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to get details of container."
  echo "  Raw response data from API is as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
echo "Existence confirmed."
echo


#
# Initiate the image export
echo "Attempting to export image to Cloud Files."
  doCurl $( cat <<EOF
             $SRCIMGURL/tasks \
             -X POST \
             -H "Content-Type: application/json" \
             -H "Accept: application/json" \
             -H "X-Auth-Token: $SRCAUTHTOKEN" \
             -H "X-Auth-Project-Id: $SRCTENANTID" \
             -H "X-Tenant-Id: $SRCTENANTID" \
             -H "X-User-Id: $SRCTENANTID" \
             -d '{ "type": "export",
                   "input": {
                     "image_uuid": "'$SRCIMGID'",
                     "receiving_swift_container": "'$CONTAINER'" } }'
EOF
)
if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to initiate export task - reason unknown."
  echo "Response data from API was as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
DATA=$( echo "$DATA" | sed '$d' )
SRCTASKID=$( echo "$DATA" | tr ',' '\n' | grep '"id":' | cut -d'"' -f4 )
EXPORTED=1
echo "Successully initiated an image export task in region '$SRCRGN'."
echo "Task ID: $SRCTASKID"
echo


#
# Wait for export to complete
INTERVAL=60
echo "Monitoring status of image export."
while true; do
  echo -n $( date +"%F %T" )
  echo " Waiting for completion - will check every $INTERVAL seconds."
  sleep 60
  doCurl $( cat <<EOF
               $SRCIMGURL/tasks/$SRCTASKID \
               -X GET \
               -H "Accept: application/json" \
               -H "Content-Type: application/json" \
               -H "X-Auth-Token: $SRCAUTHTOKEN" \
               -H "X-Auth-Project-Id: $SRCTENANTID" \
               -H "X-Tenant-Id: $SRCTENANTID" \
               -H "X-User-Id: $SRCTENANTID"
EOF
)
  if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
    echo "Error: Unable to query task details - maybe API is unavailable?"
    echo "       Maybe your API token just expired?"
    echo "Script will attempt to retry."
    echo "Response data from API was as follows:"
    echo
    echo "Response code: $CODE"
    echo "$DATA" | sed '$d' && cleanup
  fi
  STATUS=$( echo "$DATA" | tr ',' '\n' | grep '"status":' | cut -d'"' -f4 )
  if [[ "$STATUS" == "pending" ||
        "$STATUS" == "processing" ]]; then
    continue # Keep waiting
  else
    if [ "$STATUS" == "success" ]; then
      break
    else
      echo "Error: Export task complete, but status does not indicate success."
      echo "Most likely, license restrictions prevent this image from being exported."
      echo "Status: $STATUS"
      echo -n "Message: "
      echo "$DATA" | tr ',' '\n' | grep '"message":' | cut -d'"' -f4
      cleanup
    fi
  fi
done
echo "Export task completed successfully."
echo


#
# Create container at destination to store image segments
# Presently the "." character is considered invalid by the export task
#   when used as the name of a Cloud Files container.  Since "." is 
#   likely very common in image names (ie: FQDNs), I'm not including
#   the image name as part of the container name - it would cause the
#   export task validation to fail.  Once the bug is resolved, I'll
#   change this, but in the meantime we'll use just the timestamp as
#   the container name.
#CONTAINER="$IMGNAME-$DATE"
CONTAINER="img-copy-$DATE"
echo "Creating Cloud Files container ($CONTAINER) on account $DSTTENANTID to store files for import."
  doCurl $( cat <<EOF
             $DSTFILEURL/$CONTAINER \
             -X PUT \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $DSTAUTHTOKEN"
EOF
)
if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to create container '$CONTAINER' in region '$DSTRGN'"
  echo "  on account $DSTTENANTID."
  echo "  Does it already exist?  Raw response data from API is as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
MADEDSTCONT=1
echo "Successully created container in region '$DSTRGN' on account $DSTTENANTID."
echo


#
# Confirm the existence of Destination Cloud Files container
echo "Attempting to confirm Cloud Files container does now exist on account $DSTTENANTID."
  doCurl $( cat <<EOF
             $DSTFILEURL/$CONTAINER \
             -X GET \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $DSTAUTHTOKEN"
EOF
)
if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to get details of container."
  echo "  Raw response data from API is as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
echo "Existence confirmed."
echo


#
# Create a local folder in which to store interim data
SAVELOCAL=1
mkdir /tmp/$CONTAINER


#
# Kludgy workaround to account for the problem that sometimes,
#   Cloud Files is missing some objects from the container listing.
echo "Attempting to enumerate all file segments exported to Cloud Files."
echo "Will attempt 3 times in 60-second intervals."
SEGMENTS=""
for x in $( seq 1 3 ); do
  echo "Sleeping 60 seconds."
  sleep 60
  #
  # Pull a list of all image segment files
  echo "Pulling container listing."
  doCurl $( cat <<EOF
               $SRCFILEURL/$CONTAINER \
               -X GET \
               -H "Accept: application/json" \
               -H "Content-Type: application/json" \
               -H "X-Auth-Token: $SRCAUTHTOKEN"
EOF
)
  if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
    echo "Error: Unable to get details of container."
    echo "  Raw response data from API is as follows:"
    echo
    echo "Response code: $CODE"
    echo "$DATA" | sed '$d' && cleanup
  fi
  SEGMENTS=$( echo "$SEGMENTS";
              echo "$DATA" | tr ',' '\n' | grep '"name":\|"hash":' |
                cut -d'"' -f4 | sed 'N;s/\n/:/' | grep "$SRCIMGID.vhd-" )
done
SEGMENTS=$( echo "$SEGMENTS" | sort -t : -k 2 | uniq | sed '/^\s*$/d' )
echo "Successfully retrieved container listing."
(
  echo "md5sum:filename" 
  echo "$SEGMENTS"
) | column -s : -t
echo


#
# Problems on this next part.  Turns out I need to restructure doCurl
#   so that the data comes out through STDOUT.  Or, I switch to wget or
#   something or tell curl to write directly to file.  In my past
#   experience though, curl has a bug regarding interaction with file
#   handles via -T or whatever.  Future problems for future me.
exit 0


#
# Download/Upload loop
# Transfer 1 segment at a time to DSTRGN, verifying md5sums
TOTAL=$( echo "$SEGMENTS" | wc -l )
COUNT=0
for SEGMENT in $SEGMENTS; do
  MD5SUM=$( echo $SEGMENT | cut -d: -f1 )
  OBJECT=$( echo $SEGMENT | cut -d: -f2- )
  COUNT=$(( $COUNT + 1 ))
  # Download a segment
  echo "$(date +'%F %T') ($COUNT/$TOTAL) Downloading segment: $OBJECT"
  while true; do
    doCurl $( cat <<EOF
         $SRCFILEURL/$CONTAINER/$OBJECT \
         -X GET \
         -H "X-Auth-Token: $SRCAUTHTOKEN"
EOF
) >/tmp/$CONTAINER/$OBJECT 2>/dev/null
    echo "$(date +'%F %T') ($COUNT/$TOTAL) Download complete.  Verifying integrity."
    if [ -f /tmp/$CONTAINER/$OBJECT ]; then
      LOCALMD5=$( md5sum /tmp/$CONTAINER/$OBJECT | awk '{print $1}' )
      if [ "$LOCALMD5" == "$MD5SUM" ]; then
        break
      else
        echo "$(date +'%F %T') ($COUNT/$TOTAL) Error: MD5 sum of downloaded file does not match.  Retrying."
      fi
    else
      echo "$(date +'%F %T') ($COUNT/$TOTAL) Error: File not found locally after download.  Retrying."
    fi
  done
  echo "$(date +'%F %T') ($COUNT/$TOTAL) Local copy matches md5sum of Cloud Files object in $SRCRGN."
  # Upload, enforcing md5sum
  echo "$(date +'%F %T') ($COUNT/$TOTAL) Uploading segment to $DSTRGN."
  while true; do
    DATA=$( curl --write-out \\n%{http_code} --silent --output - \
                 $DSTFILEURL/$CONTAINER/$OBJECT \
                 -T /tmp/$CONTAINER/$OBJECT \
                 -X PUT \
                 -H "X-Auth-Token: $DSTAUTHTOKEN" \
                 -H "ETag: $MD5SUM" \
              2>/dev/null )
    RETVAL=$?
    CODE=$( echo "$DATA" | tail -n 1 )
    # Code 422 indicates checksum validation failure
    if [ $RETVAL -ne 0 ]; then
      echo "Unknown error encountered when trying to run curl command." && cleanup
    fi
    if [ $CODE -eq 422 ]; then
      echo "$(date +'%F %T') ($COUNT/$TOTAL) Error: Checksum validation failed.  Retrying."
      continue
    else
      if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
        echo "Error: File upload failed for unknown reason."
        echo "  Raw response data from API is as follows:"
        echo
        echo "Response code: $CODE"
        echo "$DATA" | sed '$d' && cleanup
      else
        break
      fi
    fi
  done
  echo "$(date +'%F %T') ($COUNT/$TOTAL) Segment uploaded successfully."
  echo "$(date +'%F %T') ($COUNT/$TOTAL) Checksum validated."
  # Delete the local copy of $SEGMENT
  rm -f /tmp/$CONTAINER/$OBJECT
  echo "$(date +'%F %T') ($COUNT/$TOTAL) Local copy of segment deleted."
done
rmdir /tmp/$CONTAINER
SAVELOCAL=0
echo


#
# Delete Cloud Files objects & container at $SRCRGN
echo "Deleting content of container $CONTAINER from $SRCRGN on account $SRCTENANTID."
for SEGMENT in $SEGMENTS; do
  # Delete all the segments
  OBJECT=$( echo $SEGMENT | cut -d: -f2- )
  DATA=$( curl --write-out \\n%{http_code} --silent --output - \
               $SRCFILEURL/$CONTAINER/$OBJECT \
               -X DELETE \
               -H "X-Auth-Token: $SRCAUTHTOKEN" \
            2>/dev/null )
  RETVAL=$?
  CODE=$( echo "$DATA" | tail -n 1 )
  if [ $RETVAL -ne 0 ]; then
    echo "Unknown error encountered when trying to run curl command." && cleanup
  elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
    echo "Error: Unable to delete $OBJECT from $CONTAINER in $SRCRGN"
    echo "Response from API was the following:"
    echo
    echo "Response code: $CODE"
    echo "$DATA" | sed '$d' && cleanup
  fi
done
# Delete the manifest file
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $SRCFILEURL/$CONTAINER/$SRCIMGID.vhd \
             -X DELETE \
             -H "X-Auth-Token: $SRCAUTHTOKEN" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to delete $SRCIMGID.vhd from $CONTAINER in $SRCRGN on account $SRCTENANTID"
  echo "Response from API was the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
echo "Contents successfully deleted from $SRCRGN on account $SRCTENANTID."
echo


#
# Delete the $SRCRGN container
echo "Deleting container $CONTAINER from $SRCRGN on account $SRCTENANTID."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $SRCFILEURL/$CONTAINER \
             -X DELETE \
             -H "X-Auth-Token: $SRCAUTHTOKEN" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to delete container in $SRCRGN on account $SRCTENANTID"
  echo "Response from API was the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
MADESRCCONT=0
echo "Container deleted successfully."
echo


#
# Create a dynamic manifest object
echo "Creating dynamic manifest file $SRCIMGID.vhd on account $DSTTENANTID"
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $DSTFILEURL/$CONTAINER/$SRCIMGID.vhd \
             -T /dev/null \
             -X PUT \
             -H "X-Auth-Token: $DSTAUTHTOKEN" \
             -H "X-Object-Manifest: $CONTAINER/${SRCIMGID}.vhd-" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to create empty manifest file in $DSTRGN on account $DSTTENANTID"
  echo "Response from API was the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
echo "Manifest file created successfully."
echo


#
# Start an import task on the manifest file
echo "Initiating import task in $DSTRGN."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $DSTIMGURL/tasks \
             -X POST \
             -H "Content-Type: application/json" \
             -H "Accept: application/json" \
             -H "X-Auth-Token: $DSTAUTHTOKEN" \
             -H "X-Auth-Project-Id: $DSTTENANTID" \
             -H "X-Tenant-Id: $DSTTENANTID" \
             -H "X-User-Id: $DSTTENANTID" \
             -d '{ "type": "import",
                   "input": {
                     "import_from": "'$CONTAINER'/'$SRCIMGID'.vhd",
                     "import_from_format": "vhd", 
                     "image_properties": {
                       "name": "'"$IMGNAME"'" } } }' \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to initiate import task - reason unknown."
  echo "Response from API was as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | sed '$d' && cleanup
fi
DATA=$( echo "$DATA" | sed '$d' )
DSTTASKID=$( echo "$DATA" | tr ',' '\n' | grep '"id":' | cut -d'"' -f4 )
IMPORTED=1
echo "Successully initiated an image import task in region '$DSTRGN'."
echo "Task ID: $DSTTASKID"
echo


#
# Wait for import to complete
INTERVAL=60
echo "Monitoring status of image import."
while true; do
  echo -n $( date +"%F %T" )
  echo " Waiting for completion - will check every $INTERVAL seconds."
  sleep 60
  DATA=$( curl --write-out \\n%{http_code} --silent --output - \
               $DSTIMGURL/tasks/$DSTTASKID \
               -X GET \
               -H "Accept: application/json" \
               -H "Content-Type: application/json" \
               -H "X-Auth-Token: $DSTAUTHTOKEN" \
               -H "X-Auth-Project-Id: $DSTTENANTID" \
               -H "X-Tenant-Id: $DSTTENANTID" \
               -H "X-User-Id: $DSTTENANTID" \
            2>/dev/null )
  RETVAL=$?
  CODE=$( echo "$DATA" | tail -n 1 )
  # Check for failed API call
  if [ $RETVAL -ne 0 ]; then
    echo "Unknown error encountered when trying to run curl command." && cleanup
  elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
    echo "Error: Unable to query task details - maybe API is unavailable?"
    echo "       Maybe your API token just expired?"
    echo "Script will attempt to retry."
    echo "Response data from API was as follows:"
    echo
    echo "Response code: $CODE"
    echo "$DATA" | sed '$d' && cleanup
  fi
  STATUS=$( echo "$DATA" | tr ',' '\n' | grep '"status":' | cut -d'"' -f4 )
  if [[ "$STATUS" == "pending" ||
        "$STATUS" == "processing" ]]; then
    continue # Keep waiting
  else
    if [ "$STATUS" == "success" ]; then
      break
    else
      echo "Error: Import task complete, but status does not indicate success."
      echo "Status: $STATUS"
      echo -n "Message: "
      echo "$DATA" | tr ',' '\n' | grep '"message":' | cut -d'"' -f4 && cleanup
    fi
  fi
done
echo "Import task completed successfully."
echo


#
# Report success
echo "Transfer complete."
echo "Image ID $SRCIMGID copied from $SRCRGN on account $SRCTENANTID to $DSTRGN on account $DSTTENANTID."
echo "Cloud Files content in $SRCRGN on account $SRCTENANTID was auto-deleted."
echo "Cloud Files content in $DSTRGN on account $DSTTENANTID left in place - delete manually if necessary."
exit 0

