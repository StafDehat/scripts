#!/bin/bash

FILES_ENDPOINT="https://storage101.lon3.clouddrive.com/v1"
#FILES_ENDPOINT="https://storage101.syd2.clouddrive.com/v1"
#FILES_ENDPOINT="https://storage101.dfw1.clouddrive.com/v1"
#FILES_ENDPOINT="https://storage101.iad3.clouddrive.com/v1"
#FILES_ENDPOINT="https://storage101.hkg1.clouddrive.com/v1"
#FILES_ENDPOINT="https://storage101.ord1.clouddrive.com/v1"
VAULTNAME=""
AUTHTOKEN=""

# Get a list of all containers on this account/region
CONTAINERS="$( curl $FILES_ENDPOINT/$VAULTNAME?format=json \
                    -X GET \
                    -H "X-Auth-Token: $AUTHTOKEN" |
                python -m json.tool | 
                sed -n '/^\s*"name": /s/^\s*"name": "\(.*\)"\s*$/\1/p' |
                sort -nr )"
while read CONTAINER; do
  # Get a list of all objects in the container
  OBJECTS="$( curl $FILES_ENDPOINT/$VAULTNAME/$CONTAINER?format=json \
                   -X GET \
                   -H "X-Auth-Token: $AUTHTOKEN" | 
                python -m json.tool | 
                sed -n '/^\s*"name": /s/^\s*"name": "\(.*\)"\s*$/\1/p' |
                sort -nr )"
  # Delete all objects in the container
  while read OBJECT; do
    # Delete one object
    curl "$FILES_ENDPOINT/$VAULTNAME/$CONTAINER/$OBJECT" \
         -X DELETE \
         -H "X-Auth-Token: $AUTHTOKEN"
  done <<<"$OBJECTS"
  # Delete the container
  curl "$FILES_ENDPOINT/$VAULTNAME/$CONTAINER" \
       -X DELETE \
       -H "X-Auth-Token: $AUTHTOKEN"
done <<<"$CONTAINERS"

