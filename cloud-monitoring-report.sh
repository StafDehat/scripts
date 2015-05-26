#!/bin/bash
# Author: Andrew Howard

read -p "Enter account's username: " -s USERNAME
read -p "Enter account's API Key: " -s APIKEY

IDENTITY_ENDPOINT="https://identity.api.rackspacecloud.com/v2.0"
MONITOR_ENDPOINT="https://monitoring.api.rackspacecloud.com/v1.0"

#
# Record authtoken and DDI
DATA=$(curl -s $IDENTITY_ENDPOINT/tokens \
            -H "Content-Type: application/json" \
            -d '{ "auth": { 
                  "RAX-KSKEY:apiKeyCredentials": {
                    "apiKey": "'$APIKEY'",
                    "username": "'$USERNAME'" } } }' \
            2>/dev/null )
unset USERNAME
unset APIKEY
DATA=$( echo "$DATA" | 
          tr '}{,' '\n' | 
          sed -n '/token/,/serviceCatalog/p' )
AUTHTOKEN=$( echo "$DATA" |
               sed '/tenant/,/^\s*$/d' |
               grep '"id":' |
               cut -d\" -f4 )
TENANTID=$( echo "$DATA" |
              sed -n '/tenant/,/^\s*$/p' |
              grep '"id":' |
              cut -d\" -f4 )

#
# Pull a list of entities
ENTITIES=$( curl $MONITOR_ENDPOINT/$TENANTID/entities \
                 -X GET \
                 -H "Content-Type: application/json" \
                 -H "X-Auth-Token: $AUTHTOKEN" \
                 2>/dev/null )
ENTITYIDS=$( echo "$ENTITIES" |
               grep '"id":' | 
               cut -d\" -f4 )

#
# For each entity, pull a list of monitors
for ENTITYID in $ENTITYIDS; do
  CHECKS=$( curl $MONITOR_ENDPOINT/$TENANTID/entities/$ENTITYID/checks \
                 -X GET \
                 -H "Content-Type: application/json" \
                 -H "X-Auth-Token: $AUTHTOKEN" \
                 2>/dev/null )
  CHECKIDS=$( echo "$CHECKS" |
                grep '"id":' | 
               cut -d\" -f4 )
  
done

