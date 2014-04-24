#!/bin/bash
echo "This script is not meant to be run directly"
echo "It's intended as a reference only - read it, don't run it."
exit 0

# These are the variables you'll need to set
LOCALFILE=/home/rack/image.vhd
FILES_VAULT=MossoCloudFS_3ce9abd8-cbc7-11e3-9eee-27700cf6687a
FILES_ENDPOINT=https://storage101.dfw1.clouddrive.com/v1
CONTAINER=MyContainer
CFNAME=MyBigFile

# Split the file into segments
# There's some extra crap here to get all the segments in a
#   directory by their lonesome.
LOCALDIR=$( dirname $LOCALFILE )
LOCALFILE=$( basename $LOCALFILE )
mkdir $LOCALDIR/temp-filesplit
cd $LOCALDIR/temp-filesplit
mv ../$LOCALFILE .
split -d -b 1073741824 $LOCALFILE ${LOCALFILE}-
mv $LOCALFILE ../

# At this point the easiest way is to use Dave Kludt's cfiles script.
# I've updated it to include all regions:
# https://raw.githubusercontent.com/StafDehat/scripts/master/cloud-files.sh
# When it asks for the Local Path, use $LOCALDIR/temp-filesplit

# Create a dynamic manifest file:
curl --write-out \\n%{http_code} --silent --output - \
     $FILES_ENDPOINT/$FILES_VAULT/$CONTAINER/$CFNAME \
     -T /dev/null \
     -X PUT \
     -H "X-Auth-Token: $BRC_AUTHTOKEN" \
     -H "X-Object-Manifest: $CONTAINER/${CFNAME}-"
