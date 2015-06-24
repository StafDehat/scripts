#!/bin/bash

#
# Author: Andrew Howard
# Create an image of a Cloud Server.
#

IDENTITY_ENDPOINT="https://identity.api.rackspacecloud.com/v2.0"

function errorcurlfail() {
  echo "ERROR: Unexpected error occurred while attempting to perform a curl command."
  exit 1
}

function errornot200() {
  CODE=$1
  shift 1
  echo "$@"
  echo
  echo "ERROR: API call unsuccessful"
  echo "Response code: $CODE"
  echo "Raw response data above."
  exit 1
}

function usage() {
  echo "Usage: cloud-create-image.sh [-h] -u API_USER \\"
  echo "                                  -p API_PASSWORD \\"
  echo "                                  -r REGION \\"
  echo "                                  -s SERVER_ID \\"
  echo "                                  -n IMAGE_NAME"
  echo "Example:"
  echo "  # cloud-create-image.sh -u rackuser1 \\"
  echo "                          -p 'P@ssw0rd' \\"
  echo "                          -r dfw \\"
  echo "                          -s e5576a8c-cafd-11e3-8efc-af2ba969cd6f \\"
  echo "                          -n server01-2014-03-16"
}

USAGEFLAG=0
API_USER=""
API_PASSWORD=""
REGION=""
SERVER_ID=""
IMAGE_NAME=""
while getopts ":hn:p:r:s:u:" arg; do
  case $arg in
    h) usage && exit 0;;
    n) IMAGE_NAME=$OPTARG;;
    p) API_PASSWORD=$OPTARG;;
    r) REGION=$OPTARG;;
    s) SERVER_ID=$OPTARG;;
    u) API_USER=$OPTARG;;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))

for ARG in API_USER API_PASSWORD REGION SERVER_ID IMAGE_NAME; do
  if [ -z "${!ARG}" ]; then
    echo "ERROR: Must define $ARG in environment or argument"
    USAGEFLAG=1
  fi
done

if [ $USAGEFLAG -ne 0 ]; then
  usage && exit 1
fi


#
# Authenticate to get a token
DATA=$( curl --write-out \\n%{http_code} --silent \
             https://identity.api.rackspacecloud.com/v2.0/tokens \
             -X POST \
             -H "Content-Type: application/json" \
             -d '{ "auth": { 
                     "passwordCredentials": { 
                       "username":"'"${API_USER}"'",
                       "password":"'"${API_PASSWORD}"'"} } }' \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
if [ $RETVAL -ne 0 ]; then
  errorcurlfail
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  errornot200 $CODE $( echo "$DATA" | sed '$d' )
fi
# Record the Token, set the AuthToken and DDI
TOKEN=$( echo "$DATA" | sed '$d' )
AUTHTOKEN=$( echo "$TOKEN" | perl -pe 's/.*"token":.*?"id":"(.*?)".*$/\1/' )
TENANTID=$( echo "$TOKEN" | perl -pe 's/.*"token":.*?"tenant":.*?"id":"(.*?)".*$/\1/' )


# 
# Send the image-create signal
REGION=$( tr 'A-Z' 'a-z' <<<"$REGION" )
DATA=$( curl -D - --write-out \\n%{http_code} --silent \
             https://$REGION.servers.api.rackspacecloud.com/v2/$TENANTID/servers/${SERVER_ID}/action \
             -X POST \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: ${AUTHTOKEN}" \
             -d '{ "createImage": {
                     "name": "'"${IMAGE_NAME}"'" } }' \
          2>/dev/null )
RETVAL=$?
CODE=$( echo "$DATA" | tail -n 1 )
if [ $RETVAL -ne 0 ]; then
  errorcurlfail
elif [[ $(echo "$CODE" | grep -cE '^2..$') -eq 0 ]]; then
  errornot200 $CODE $( echo "$DATA" | sed '$d' )
fi


#
# Report results
echo "Image creation initialized successfully."
echo
echo "Response headers from API:"
echo "$DATA" | sed '$d'



