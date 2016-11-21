#!/bin/bash

# Author: Andrew Howard
# Purpose: Take an image, then delete the oldest images until only $RETENTION
#   images remain.  This script is intended to be cron'd, probably daily.

# Note: User must have 'Admin' access to both "Images" and "Next Generation Servers"
CLOUD_USERNAME=
CLOUD_API_KEY=
SERVER_ID=
REGION=iad
RETENTION=3

if [[ -f "${HOME}"/.cloud-daily-image.cfg ]]; then
  source "${HOME}"/.cloud-daily-image.cfg
fi

#TODO: Take arguments
#TODO: Integrate with Cloud Monitorings... somehow.

IDENTITY_ENDPOINT="https://identity.api.rackspacecloud.com/v2.0"

# Get an Auth token
echo "Authenticating to API"
TOKEN=$( curl -s $IDENTITY_ENDPOINT/tokens \
           -H "Content-Type: application/json" \
           -d '{ "auth": { 
                 "RAX-KSKEY:apiKeyCredentials": {
                   "apiKey": "'$CLOUD_API_KEY'",
                   "username": "'$CLOUD_USERNAME'" } } }' 2>/dev/null )
AUTHTOKEN=$( echo "$TOKEN" | perl -pe 's/.*"token":.*?"id":"(.*?)".*$/\1/' )
TENANTID=$( echo "$TOKEN" | perl -pe 's/.*"token":.*?"tenant":.*?"id":"(.*?)".*$/\1/' )
IMGURL=$( echo "$TOKEN" | tr '"' '\n' | grep "$REGION.images.api.rackspacecloud.com" | tr -d '\\' )
# TODO: Detect authentication failures, print a meaningful error, and exit

#TODO: Verify server's not already imaging.  If so, bail, or wait-loop.

# Create a new image
echo "Creating new image"
IMAGE_NAME="Daily-$( awk -F - '{print $NF}' <<<"${SERVER_ID}" )"
curl -s https://${REGION}.servers.api.rackspacecloud.com/v2/${TENANTID}/servers/${SERVER_ID}/action \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "X-Auth-Token: $AUTHTOKEN" \
  -d '{ "createImage" : { "name" : "'"${IMAGE_NAME}"'" } }'
#TODO: Capture the image ID of the new one

# List existing images
echo "Retrieving list of images"
IMAGES=$( curl -s "${IMGURL}/images?status=ACTIVE&instance_uuid=${SERVER_ID}&name=${IMAGE_NAME}" \
            -X GET \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "X-Auth-Token: $AUTHTOKEN" \
            -H "X-Auth-Project-Id: $TENANTID" \
            -H "X-Tenant-Id: $TENANTID" \
            -H "X-User-Id: $TENANTID" )

# Strip 'em down to just ID and Date (in epoch), then get 'em side-by-side
IMAGEIDS=$( tr ',' '\n' <<<"${IMAGES}" |
              grep -Po '"id":.*' |
              cut -d\" -f4 )
IMAGEDATES=$( tr ',' '\n' <<<"${IMAGES}" |
              grep -Po '"created_at":.*' |
              cut -d\" -f4 )
echo "Previous images:"
paste <(echo "$IMAGEDATES")  <(echo "$IMAGEIDS") | sort -n
# TODO: Print image currently being imaging
echo "Plus the one that's being created right now"
IMAGEDATES=$( while read DATE; do
               date -d "${DATE}" +%s
             done <<<"$IMAGEDATES" )

# Sort by date, and grab all but ${RETENTION} images
DELETABLE=$( paste <(echo "$IMAGEDATES")  <(echo "$IMAGEIDS") |
               sort -nr |
               tail -n +${RETENTION} |
               awk '{print $2}' )

#TODO: Wait for image to finish successfully before reaping old

# Delete the old ones
echo "Deleting down to ${RETENTION} images"
for IMAGE in ${DELETABLE}; do
  echo "Deleting old image ${IMAGE}"
  curl -s "${IMGURL}/images/${IMAGE}" \
    -X DELETE \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Token: $AUTHTOKEN" \
    -H "X-Auth-Project-Id: $TENANTID" \
    -H "X-Tenant-Id: $TENANTID" \
    -H "X-User-Id: $TENANTID"
done


