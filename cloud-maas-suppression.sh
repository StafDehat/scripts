#!/bin/bash

# Author: Andrew Howard

# It's recommended to create a user specifically for suppressions
# This user should have *only* "Creator" access to *only* "Monitoring"
CLOUD_USERNAME=""
CLOUD_API_KEY=""
# LENGTH can be anything that "date -d" can process
LENGTH="2 hours"

declare -a ENTITIES
ENTITIES+=( 'ent01' )
ENTITIES+=( 'ent02' )

START=0 # '0' means 'now'
END=$(( $(date +%s --date="$LENGTH") * 1000 ))

# Define endpoints
IDENTITY_ENDPOINT="https://identity.api.rackspacecloud.com/v2.0"
MONITORING_ENDPOINT="https://monitoring.api.rackspacecloud.com/v1.0"

# Authenticate and snatch an Auth Token and TenantID (ie: DDI)
TOKEN=$( curl -s $IDENTITY_ENDPOINT/tokens \
           -H "Content-Type: application/json" \
           -d '{ "auth": { 
                 "RAX-KSKEY:apiKeyCredentials": {
                   "apiKey": "'$CLOUD_API_KEY'",
                   "username": "'$CLOUD_USERNAME'" } } }' 2>/dev/null )
AUTHTOKEN=$( echo "$TOKEN" | perl -pe 's/.*"token":.*?"id":"(.*?)".*$/\1/' )
TENANTID=$( echo "$TOKEN" | perl -pe 's/.*"token":.*?"tenant":.*?"id":"(.*?)".*$/\1/' )

# Reformat the ENTITIES array into quoted CSV, as json expects
ENTITIES=$( sed -e 's/^/"/' -e 's/$/"/' -e 's/ /","/g' <<<"${ENTITIES[@]}" )

# Make the suppression
curl -s ${MONITORING_ENDPOINT}/${TENANTID}/suppressions \
     -X POST \
     -H "X-Auth-Token: ${AUTHTOKEN}" \
     -H "Content-type: application/json" \
     -d '{
           "start_time" : "'"${START}"'",
           "end_time"   : "'"${END}"'",
           "entities"   : [ '"${ENTITIES}"' ]
         }' 2>/dev/null

