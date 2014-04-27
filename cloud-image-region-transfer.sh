#!/bin/bash
#
# This script will copy an image from one region to another.
# BE AWARE: This will incur charges for the customer.  These charges
# can be minimized by using ServiceNet for the download and by choosing
# to auto-delete the Cloud Files content once the transfer is complete.
# Even with these precautions, the customer will be charged for storage
# fees in Cloud Files (for a single month) and Cloud Images (destination).
# Note: To use ServiceNet, this script MUST be run on a Cloud Server
# in the same region as the source image.


#
# Hard-coded variabled
IDENTITY_ENDPOINT="https://identity.api.rackspacecloud.com/v2.0"
DATE=$( date +%F-%T )


#
# Verify the existence of pre-req's
PREREQS="curl grep sed date cut tr echo column nc"
PREREQFLAG=0
for PREREQ in $PREREQS; do
  which $PREREQ >/dev/null
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
MADESRCCONT=0
MADEDSTCONT=0
EXPORTED=0
IMPORTED=0
SAVELOCAL=0


#
# Define a clean-up function and catch exit signals
function cleanup {
  echo "Script exited prematurely."
  echo "You may need to manually delete the following:"
  if [ $MADESRCCONT -ne 0 ]; then
    echo "Container $CONTAINER in Cloud Files region $SRCRGN"
  fi
  if [ $MADEDSTCONT -ne 0 ]; then
    echo "Container $CONTAINER in Cloud Files region $DSTRGN"
  fi
  if [ $EXPORTED -ne 0 ]; then
    echo "Export task $SRCTASKID in region $SRCRGN"
    echo "Really though, just confirm it's done and delete the files in $CONTAINER"
  fi
  if [ $IMPORTED -ne 0 ]; then
    echo "Import task $DSTTASKID in region $DSTRGN"
    echo "Really though, just confirm it's done and delete the image."
  fi
  if [ $SAVELOCAL -ne 0 ]; then
    echo "Folder and contents on local storage: /tmp/$CONTAINER"
  fi
  exit 1
}
trap 'cleanup' 1 2 9 15 17 19 23


#
# Usage statement
function usage() {
  echo "Usage: img-transfer.sh [-h] -S -A AUTHTOKEN -T TENANTID \\"
  echo "                       -s SRCRGN -d DSTRGN -i IMGID"
  echo "Example:"
  echo "  # img-transfer.sh -A 7a9d3410cd7d11e3a8bfabb5e3025477 \\"
  echo "                    -T 123456 \\"
  echo "                    -s dfw \\"
  echo "                    -d iad \\"
  echo "                    -i 8883bb30-cd7d-11e3-ab61-3b672f712d5f"
  echo "Arguments:"
  echo "  -A X  API authentication token."
  echo "  -d X  Destination region (DFW/ORD/IAD/etc)."
  echo "  -h    Print this help"
  echo "  -i X  Image ID.  Find in MyCloud by hovering over image name."
  echo "  -s X  Source region (DFW/ORD/IAD/etc)"
  echo "  -S    Use ServiceNet for download (Must run this script in same"
  echo "        region as defined for SRCRGN)."
  echo "  -T X  Tenant ID (DDI)."
}


#
# Confirm usage is correct, and all variables passed
USAGEFLAG=0
SNET=0
while getopts ":hA:T:s:Sd:i:" arg; do
  case $arg in
    A) AUTHTOKEN=$OPTARG;;
    d) DSTRGN=$OPTARG;;
    i) IMGID=$OPTARG;;
    s) SRCRGN=$OPTARG;;
    S) SNET=1;;
    T) TENANTID=$OPTARG;;
    h) usage && exit 0;;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))
ARGUMENTS="AUTHTOKEN TENANTID SRCRGN DSTRGN IMGID"
for ARGUMENT in $ARGUMENTS; do
  if [ -z "${!ARGUMENT}" ]; then
    echo "ERROR: Must define $ARGUMENT as argument."
    USAGEFLAG=1
  fi
done
if [ $USAGEFLAG -ne 0 ]; then
  echo && usage && exit 1
fi


#
# Put regions in lowercase.
SRCRGN=$( echo $SRCRGN | tr 'A-Z' 'a-z' )
DSTRGN=$( echo $DSTRGN | tr 'A-Z' 'a-z' )


#
# TENANTID and AUTHTOKEN can't work in both LON and any other region,
#   so if either is LON then this script can't quite work.  Maybe in
#   a future version.  I'd have to prompt for both SRC and DST auth
#   tokens & DDIs though.
if [[ "$SRCRGN" == "lon" ||
      "$DSTRGN" == "lon" ]]; then
  echo "Sorry kids, this script can't work with LON yet."
  echo "Maybe in a future version."
  echo "Read the source and you might be able to sqeak by."
  exit 1
fi


#
# Auth against API, both to confirm DDI/Token, and to get
#   endpoints & Cloud Files Vault ID
echo "Attempting to authenticate against Identity API."
DATA=$(curl --write-out \\n%{http_code} --silent --output - \
            $IDENTITY_ENDPOINT/tokens \
            -H "Content-Type: application/json" \
            -d '{ "auth": {
                    "tenantId": "'$TENANTID'",
                    "token": {
                      "id": "'$AUTHTOKEN'" } } }' \
         2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to authenticate against API using AUTHTOKEN and TENANTID"
  echo "  provided.  Raw response data from API was the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
echo "Successfully authenticated using provided AUTHTOKEN and TENANTID."
echo
TOKEN=$( echo "$DATA" | head -n -1 )


#
# Find the Images endpoints
echo "Attempting to identify Image API endpoints."
if [ "$SRCRGN" == "lon" ]; then
  SRCIMGURL="https://lon.images.api.rackspacecloud.com/v2/$TENANTID"
else
  SRCIMGURL=$( echo "$TOKEN" | tr '"' '\n' | grep "$SRCRGN.images.api.rackspacecloud.com" | tr -d '\\' )
fi
if [ "$DSTRGN" == "lon" ]; then
  DSTIMGURL="https://lon.images.api.rackspacecloud.com/v2/$TENANTID"
else
  DSTIMGURL=$( echo "$TOKEN" | tr '"' '\n' | grep "$DSTRGN.images.api.rackspacecloud.com" | tr -d '\\' )
fi
echo "Identified Images API endpoints:"
echo "Source:      $SRCIMGURL"
echo "Destination: $DSTIMGURL"
echo 


#
# Verify IMGID exists in SRCRGN
echo "Verifying image exists."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $SRCIMGURL/images/$IMGID \
             -X GET \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $AUTHTOKEN" \
             -H "X-Auth-Project-Id: $TENANTID" \
             -H "X-Tenant-Id: $TENANTID" \
             -H "X-User-Id: $TENANTID" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to get details of source image - does it exist?  Did"
  echo "  you specify the correct SRCRGN?  Raw response data from API was"
  echo "  the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
IMGNAME=$( echo "$DATA" | tr ',' '\n' | grep '"name":' | cut -d'"' -f4 )
echo "Image successfully located in region '$SRCRGN'."
echo "Image name: $IMGNAME"
echo


#
# Determine the Cloud Files endpoints
# I am, unfortunately, forced to hard-code these URLs since the TOKEN
#   does not include Cloud Files URLs - only the Vault ID.
VAULTID=$( echo "$TOKEN" | tr '"' '\n' | grep MossoCloudFS )
if [ "$SNET" -eq 1 ]; then
  SRCFILEURL="https://snet-"
else 
  SRCFILEURL="https://"
fi
case $SRCRGN in
  ord) SRCFILEURL="${SRCFILEURL}storage101.ord1.clouddrive.com/v1/$VAULTID";;
  dfw) SRCFILEURL="${SRCFILEURL}storage101.dfw1.clouddrive.com/v1/$VAULTID";;
  hkg) SRCFILEURL="${SRCFILEURL}storage101.hkg1.clouddrive.com/v1/$VAULTID";;
  lon) SRCFILEURL="${SRCFILEURL}storage101.lon3.clouddrive.com/v1/$VAULTID";;
  iad) SRCFILEURL="${SRCFILEURL}storage101.iad3.clouddrive.com/v1/$VAULTID";;
  syd) SRCFILEURL="${SRCFILEURL}storage101.syd2.clouddrive.com/v1/$VAULTID";;
    *) echo "ERROR: Unrecognized REGION code." && cleanup;;
esac
case $DSTRGN in
  ord) DSTFILEURL="https://storage101.ord1.clouddrive.com/v1/$VAULTID";;
  dfw) DSTFILEURL="https://storage101.dfw1.clouddrive.com/v1/$VAULTID";;
  hkg) DSTFILEURL="https://storage101.hkg1.clouddrive.com/v1/$VAULTID";;
  lon) DSTFILEURL="https://storage101.lon3.clouddrive.com/v1/$VAULTID";;
  iad) DSTFILEURL="https://storage101.iad3.clouddrive.com/v1/$VAULTID";;
  syd) DSTFILEURL="https://storage101.syd2.clouddrive.com/v1/$VAULTID";;
    *) echo "ERROR: Unrecognized REGION code." && cleanup;;
esac


#
# Confirm connectivity to servicenet, if necessary
if [ $SNET -eq 1 ]; then
  echo "Testing connectivity to ServiceNet."
  SNETHOST=$( echo "$SRCFILEURL" | cut -d/ -f3 )
  nc -w 5 -z snet-storage101.iad3.clouddrive.com 80
  if [ $? -ne 0 ]; then
    echo "Error: Unable to reach Cloud Files API over ServiceNet."
    echo "You may have to use public traffic instead."
    exit 1
  fi
  echo "Connection to $SNETHOST:80 successful."
  echo
fi


#
# Create a container in which to save the exported image
CONTAINER="$IMGNAME-$DATE"
echo "Creating Cloud Files container ($CONTAINER) to house exported image."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $SRCFILEURL/$CONTAINER \
             -X PUT \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $AUTHTOKEN" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to create container '$CONTAINER' in region '$SRCRGN'."
  echo "  Does it already exist?  Raw response data from API is as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
MADESRCCONT=1
echo "Successully created container in region '$SRCRGN'."
echo


#
# Confirm the existence of Source Cloud Files container
echo "Attempting to confirm Cloud Files container does now exist."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $SRCFILEURL/$CONTAINER \
             -X GET \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $AUTHTOKEN" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to get details of container."
  echo "  Raw response data from API is as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
echo "Existence confirmed."
echo


#
# Initiate the image export
echo "Attempting to export image to Cloud Files."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $SRCIMGURL/tasks \
             -X POST \
             -H "Content-Type: application/json" \
             -H "Accept: application/json" \
             -H "X-Auth-Token: $AUTHTOKEN" \
             -H "X-Auth-Project-Id: $TENANTID" \
             -H "X-Tenant-Id: $TENANTID" \
             -H "X-User-Id: $TENANTID" \
             -d '{ "type": "export",
                   "input": {
                     "image_uuid": "'$IMGID'",
                     "receiving_swift_container": "'$CONTAINER'" } }' \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to initiate export task - reason unknown."
  echo "Response data from API was as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
DATA=$( echo "$DATA" | head -n -1 )
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
  DATA=$( curl --write-out \\n%{http_code} --silent --output - \
               $SRCIMGURL/tasks/$SRCTASKID \
               -X GET \
               -H "Accept: application/json" \
               -H "Content-Type: application/json" \
               -H "X-Auth-Token: $AUTHTOKEN" \
               -H "X-Auth-Project-Id: $TENANTID" \
               -H "X-Tenant-Id: $TENANTID" \
               -H "X-User-Id: $TENANTID" \
            2>/dev/null )
  RETVAL=$?
  CODE=$( echo "$DATA" | tail -n 1 )
  # Check for failed API call
  if [ $RETVAL -ne 0 ]; then
    echo "Unknown error encountered when trying to run curl command." && cleanup
  elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
    echo "Error: Unable to query task details - maybe API is unavailable?"
    echo "Script will attempt to retry."
    echo "Response data from API was as follows:"
    echo
    echo "Response code: $CODE"
    echo "$DATA" | head -n -1
  fi
  STATUS=$( echo "$DATA" | tr ',' '\n' | grep '"status":' | cut -d'"' -f4 )
  if [[ "$STATUS" == "pending" ||
        "$STATUS" == "processing" ]]; then
    continue # Keep waiting
  else
    if [ $STATUS == "success" ]; then
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
CONTAINER="$IMGNAME-$DATE"
echo "Creating Cloud Files container ($CONTAINER) to image for import."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $DSTFILEURL/$CONTAINER \
             -X PUT \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $AUTHTOKEN" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to create container '$CONTAINER' in region '$DSTRGN'."
  echo "  Does it already exist?  Raw response data from API is as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
MADEDSTCONT=1
echo "Successully created container in region '$DSTRGN'."
echo


#
# Confirm the existence of Destination Cloud Files container
echo "Attempting to confirm Cloud Files container does now exist."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $DSTFILEURL/$CONTAINER \
             -X GET \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $AUTHTOKEN" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to get details of container."
  echo "  Raw response data from API is as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
echo "Existence confirmed."
echo


#
# Create a local folder in which to store interim data
SAVELOCAL=1
mkdir /tmp/$CONTAINER


#
# Pull a list of all image segment files
echo "Attempting to enumerate all file segments exported to Cloud Files."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $SRCFILEURL/$CONTAINER \
             -X GET \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: $AUTHTOKEN" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
# Check for failed API call
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to get details of container."
  echo "  Raw response data from API is as follows:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
SEGMENTS=$( echo "$DATA" | tr ',' '\n' | grep '"name":\|"hash":' | 
              cut -d'"' -f4 | sed 'N;s/\n/:/' | grep "$IMGID.vhd-" )
echo "Successfully retrieved container listing."
(
  echo "md5sum:filename" 
  echo "$SEGMENTS"
) | column -s : -t
echo


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
  echo "($COUNT/$TOTAL) Downloading segment: $OBJECT"
  while true; do
    curl $SRCFILEURL/$CONTAINER/$OBJECT \
         -X GET \
         -H "X-Auth-Token: $AUTHTOKEN" \
      >/tmp/$CONTAINER/$OBJECT 2>/dev/null
    echo "($COUNT/$TOTAL) Download complete.  Verifying integrity."
    if [ -f /tmp/$CONTAINER/$OBJECT ]; then
      LOCALMD5=$( md5sum /tmp/$CONTAINER/$OBJECT | awk '{print $1}' )
      if [ "$LOCALMD5" == "$MD5SUM" ]; then
        break
      else
        echo "($COUNT/$TOTAL) Error: MD5 sum of downloaded file does not match.  Retrying."
      fi
    else
      echo "($COUNT/$TOTAL) Error: File not found locally after download.  Retrying."
    fi
  done
  echo "($COUNT/$TOTAL) Local copy matches md5sum of Cloud Files object in $SRCRGN."
  # Upload, enforcing md5sum
  echo "($COUNT/$TOTAL) Uploading segment to $DSTRGN."
  while true; do
    DATA=$( curl --write-out \\n%{http_code} --silent --output - \
                 $DSTFILEURL/$CONTAINER/$OBJECT \
                 -T /tmp/$CONTAINER/$OBJECT \
                 -X PUT \
                 -H "X-Auth-Token: $AUTHTOKEN" \
                 -H "ETag: $MD5SUM" \
              2>/dev/null )
    RETVAL=$?
    CODE=$( echo "$DATA" | tail -n 1 )
    # Code 422 indicates checksum validation failure
    if [ $RETVAL -ne 0 ]; then
      echo "Unknown error encountered when trying to run curl command." && cleanup
    fi
    if [ $CODE -eq 422 ]; then
      echo "($COUNT/$TOTAL) Error: Checksum validation failed.  Retrying."
      continue
    else
      if [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
        echo "Error: File upload failed for unknown reason."
        echo "  Raw response data from API is as follows:"
        echo
        echo "Response code: $CODE"
        echo "$DATA" | head -n -1 && cleanup
      else
        break
      fi
    fi
  done
  echo "($COUNT/$TOTAL) Segment uploaded successfully."
  echo "($COUNT/$TOTAL) Checksum validated."
  # Delete the local copy of $SEGMENT
  rm -f /tmp/$CONTAINER/$OBJECT
  echo "($COUNT/$TOTAL) Local copy of segment deleted."
done
rmdir /tmp/$CONTAINER
SAVELOCAL=0
echo


#
# Delete Cloud Files objects & container at $SRCRGN
echo "Deleting content of container $CONTAINER from $SRCRGN."
for SEGMENT in $SEGMENTS; do
  # Delete all the segments
  OBJECT=$( echo $SEGMENT | cut -d: -f2- )
  DATA=$( curl --write-out \\n%{http_code} --silent --output - \
               $SRCFILEURL/$CONTAINER/$OBJECT \
               -X DELETE \
               -H "X-Auth-Token: $AUTHTOKEN" \
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
    echo "$DATA" | head -n -1 && cleanup
  fi
done
# Delete the manifest file
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $SRCFILEURL/$CONTAINER/$IMGID.vhd \
             -X DELETE \
             -H "X-Auth-Token: $AUTHTOKEN" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to delete $IMGID.vhd from $CONTAINER in $SRCRGN"
  echo "Response from API was the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
echo "Contents successfully deleted from $SRCRGN."
echo


#
# Delete the $SRCRGN container
echo "Deleting container $CONTAINER from $SRCRGN."
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $SRCFILEURL/$CONTAINER \
             -X DELETE \
             -H "X-Auth-Token: $AUTHTOKEN" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to delete container in $SRCRGN"
  echo "Response from API was the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
fi
MADESRCCONT=0
echo "Container deleted successfully."
echo


#
# Create a dynamic manifest object
echo "Creating dynamic manifest file $IMGID.vhd"
DATA=$( curl --write-out \\n%{http_code} --silent --output - \
             $DSTFILEURL/$CONTAINER/$IMGID.vhd \
             -T /dev/null \
             -X PUT \
             -H "X-Auth-Token: $AUTHTOKEN" \
             -H "X-Object-Manifest: $CONTAINER/${IMGID}.vhd-" \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
if [ $RETVAL -ne 0 ]; then
  echo "Unknown error encountered when trying to run curl command." && cleanup
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  echo "Error: Unable to create empty manifest file in $DSTRGN"
  echo "Response from API was the following:"
  echo
  echo "Response code: $CODE"
  echo "$DATA" | head -n -1 && cleanup
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
             -H "X-Auth-Token: $AUTHTOKEN" \
             -H "X-Auth-Project-Id: $TENANTID" \
             -H "X-Tenant-Id: $TENANTID" \
             -H "X-User-Id: $TENANTID" \
             -d '{ "type": "import",
                   "input": {
                     "import_from": "'$CONTAINER'/'$IMGID'.vhd",
                     "import_from_format": "vhd", 
                     "image_properties": {
                       "name": "'$IMGNAME'" } } }' \
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
  echo "$DATA" | head -n -1 && cleanup
fi
DATA=$( echo "$DATA" | head -n -1 )
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
               -H "X-Auth-Token: $AUTHTOKEN" \
               -H "X-Auth-Project-Id: $TENANTID" \
               -H "X-Tenant-Id: $TENANTID" \
               -H "X-User-Id: $TENANTID" \
            2>/dev/null )
  RETVAL=$?
  CODE=$( echo "$DATA" | tail -n 1 )
  # Check for failed API call
  if [ $RETVAL -ne 0 ]; then
    echo "Unknown error encountered when trying to run curl command." && cleanup
  elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
    echo "Error: Unable to query task details - maybe API is unavailable?"
    echo "Script will attempt to retry."
    echo "Response data from API was as follows:"
    echo
    echo "Response code: $CODE"
    echo "$DATA" | head -n -1
  fi
  STATUS=$( echo "$DATA" | tr ',' '\n' | grep '"status":' | cut -d'"' -f4 )
  if [[ "$STATUS" == "pending" ||
        "$STATUS" == "processing" ]]; then
    continue # Keep waiting
  else
    if [ $STATUS == "success" ]; then
      break
    else
      echo "Error: Export task complete, but status does not indicate success."
      echo "Status: $STATUS"
      echo -n "Message: "
      echo "$DATA" | tr ',' '\n' | grep '"message":' | cut -d'"' -f4 && cleanup
    fi
  fi
done
echo "Export task completed successfully."
echo


#
# Report success
echo "Transfer complete."
echo "Image ID $IMGID copied from $SRCRGN to $DSTRGN."
echo "Cloud Files content in $SRCRGN was auto-deleted."
echo "Cloud Files content in $DSTRGN left in place - delete manually if necessary."
exit 0
