#!/bin/bash

# Author: Andrew Howard

read -p "What's the username for your cloud account? " CLOUD_USERNAME
read -p "And now enter your API key (not token): " CLOUD_API_KEY
IDENTITY_ENDPOINT="https://identity.api.rackspacecloud.com/v2.0"
TOKEN=$( curl $IDENTITY_ENDPOINT/tokens \
           -H "Content-Type: application/json" \
           -d '{ "auth": { 
                 "RAX-KSKEY:apiKeyCredentials": {
                   "apiKey": "'$CLOUD_API_KEY'",
                   "username": "'$CLOUD_USERNAME'" } } }' 2>/dev/null )
AUTHTOKEN=$( echo "$TOKEN" | perl -pe 's/.*"token":.*?"id":"(.*?)".*$/\1/' )
TENANTID=$( echo "$TOKEN" | perl -pe 's/.*"token":.*?"tenant":.*?"id":"(.*?)".*$/\1/' )

echo
echo "Here's your auth token:   $AUTHTOKEN"
echo "And your DDI (Tenant ID): $TENANTID"
