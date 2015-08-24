#!/bin/bash

echo "This is a very dangerous script and you probably don't want to run it."
echo "As such, there's a hard-coded exit at the top."
echo "If you want to get fired after all, go ahead and delete the exit."
exit 0

FILES_ENDPOINT="https://snet-storage101.lon3.clouddrive.com/v1"
#FILES_ENDPOINT="https://snet-storage101.syd2.clouddrive.com/v1"
#FILES_ENDPOINT="https://snet-storage101.dfw1.clouddrive.com/v1"
#FILES_ENDPOINT="https://snet-storage101.iad3.clouddrive.com/v1"
#FILES_ENDPOINT="https://snet-storage101.hkg1.clouddrive.com/v1"
#FILES_ENDPOINT="https://snet-storage101.ord1.clouddrive.com/v1"
VAULTNAME=""
AUTHTOKEN=""

# Get a list of all containers on this account/region
CONTAINERS="$( curl $FILES_ENDPOINT/$VAULTNAME?format=json \
                    -X GET \
                    -H "X-Auth-Token: $AUTHTOKEN" 2>/dev/null |
                python -m json.tool | 
                sed -n '/^\s*"name": /s/^\s*"name": "\(.*\)"\s*$/\1/p' )"
while read CONTAINER; do
  # Get a list of all objects in the container
  OBJECTS="$( curl $FILES_ENDPOINT/$VAULTNAME/$CONTAINER?format=json \
                   -X GET \
                   -H "X-Auth-Token: $AUTHTOKEN" 2>/dev/null | 
                python -m json.tool | 
                sed -n '/^\s*"name": /s/^\s*"name": "\(.*\)"\s*$/\1/p' |
                sort -nr )"

  # Delete all objects in the container
  while read OBJECT; do
    # Delete one object
    echo "Deleting object $CONTAINER/$OBJECT"
    curl "$FILES_ENDPOINT/$VAULTNAME/$CONTAINER/$OBJECT" \
         -X DELETE \
         -H "X-Auth-Token: $AUTHTOKEN" &
  done <<<"$OBJECTS"

  # Wait for all the deletes to be done
  while [ $( jobs -p | wc -l ) -gt 1 ]; do
    echo "Waiting for jobs to finish ($( jobs -p | wc -l ) remaining)"
    sleep 1
  done

  # Delete the container
  echo "Deleting container $CONTAINER"
  curl "$FILES_ENDPOINT/$VAULTNAME/$CONTAINER" \
       -X DELETE \
       -H "X-Auth-Token: $AUTHTOKEN"
done <<<"$CONTAINERS"
