#!/bin/bash
# Author: Andrew Howard


function cleanup {
  stty echo
  exit 1
}
trap 'cleanup' 1 2 9 15 17 19 23

function usage() {
  echo "Usage: ./cloud-monitoring-report.sh -A AuthToken -T TenantID"
  echo "Example: ./cloud-monitoring-report.sh \\"
  echo "  -A fde98037d07f44c3998440da31e410ba9088a02b206f46e18a6dfcd08a47dbe7 \\"
  echo "  -T 123456"
  echo
  echo "Arguments:"
  echo "  -A X  API token (not key) of target account."
  echo "  -T X  Tenant ID (DDI) of target account."
}

USAGEFLAG=0
AUTHTOKEN=""
TENANTID=""
while getopts ":A:T:" arg; do
  case $arg in
    A) AUTHTOKEN=${OPTARG};;
    T) TENANTID=${OPTARG};;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))
ARGUMENTS="AUTHTOKEN TENANTID"
for ARGUMENT in $ARGUMENTS; do
  if [ -z "${!ARGUMENT}" ]; then
    echo "ERROR: Must define $ARGUMENT as argument."
    USAGEFLAG=1
  fi
done


IDENTITY_ENDPOINT="https://identity.api.rackspacecloud.com/v2.0"
MONITOR_ENDPOINT="https://monitoring.api.rackspacecloud.com/v1.0"



#
# Pull a list of entity IDs/Labels
ENTITIES=$( curl -s $MONITOR_ENDPOINT/$TENANTID/entities \
                 -X GET \
                 -H "Content-Type: application/json" \
                 -H "X-Auth-Token: $AUTHTOKEN" \
                 2>/dev/null )
ENTITIES=$( echo "$ENTITIES" |
               grep '"id":\|"label":' )
ENTITYIDS=$( echo "$ENTITIES" |
               grep '"id":' |
               cut -d\" -f4 )
TOGGLE=0
ENTITIES=$( 
  while read LINE; do
    if [[ "$LINE" =~ '"id":' ]]; then
      TEMPID=$( cut -d\" -f4 <<<"$LINE" )
    else
      TEMPLBL=$( cut -d\" -f4 <<<"$LINE" )
    fi
    if [[ $TOGGLE -eq 1 ]]; then
      echo "\"$TEMPID\",\"$TEMPLBL\""
      TOGGLE=0
    else
      TOGGLE=1
    fi
  done <<<"$ENTITIES" )

echo '"Entity ID","Entity Label","Enabled Checks","Disabled Checks","Total Checks"' > /tmp/entities
echo '"Entity ID","Entity Label","Check ID","Check Label","Disabled"' > /tmp/checks


#
# For each entity, pull a list of monitors & alarms
for ENTITYID in $ENTITYIDS; do
  #
  # Get all check data into CSV sorta format
  ENTITYDATA=$( grep $ENTITYID <<<"$ENTITIES" )
  CHECKS=$( curl -s $MONITOR_ENDPOINT/$TENANTID/entities/$ENTITYID/checks \
                 -X GET \
                 -H "Content-Type: application/json" \
                 -H "X-Auth-Token: $AUTHTOKEN" \
                 2>/dev/null )
  CHECKIDS=$( grep -vP '^\s*$' <<<"$CHECKS" |
                grep '"id":' | 
                cut -d\" -f4 )
  TOGGLE=0
  CHECKS=$( grep '"id:"\|"label":\|"disabled":' <<<"$CHECKS" |
    while read LINE; do
      if [[ "$LINE" =~ '"id":' ]]; then
        TEMPID=$( cut -d\" -f4 <<<"$LINE" )
      elif [[ "$LINE" =~ '"label":' ]]; then
        TEMPLBL=$( cut -d\" -f4 <<<"$LINE" )
      else
        TEMPDISABLED=$( grep -o 'true\|false' <<<"$LINE" )
      fi
      if [[ $TOGGLE -eq 2 ]]; then
        echo "$ENTITYDATA,\"$TEMPID\",\"$TEMPLBL\",\"$TEMPDISABLED\""
        TOGGLE=0
      else
        TOGGLE=$(( $TOGGLE + 1 ))
      fi
    done )

  #
  # Fill the Entity CSV
  ONCOUNT=$( grep -c false <<<"$CHECKS" )
  OFFCOUNT=$( grep -c true <<<"$CHECKS" )
  COUNT=$(( $ONCOUNT + $OFFCOUNT ))
  grep -P "^\"$ENTITYID\"," <<<"$ENTITIES" | sed "s/$/,$ONCOUNT,$OFFCOUNT,$COUNT/" >> /tmp/entities

  #
  # Fill the Checks CSV
  grep -vP '^\s*$' <<<"$CHECKS" >> /tmp/checks


  continue

  for CHECKID in $CHECKIDS; do
    echo No-op
  done


  #
  # Get all alarm data into CSV sorta format
  ALARMS=$( curl -s $MONITOR_ENDPOINT/$TENANTID/entities/$ENTITYID/alarms \
                 -X GET \
                 -H "Content-Type: application/json" \
                 -H "X-Auth-Token: $AUTHTOKEN"
                 2>/dev/null )
  ALARMIDS=$( echo "$ALARMS" |
                grep '"id":' |
                cut -d\" -f4 )
  TOGGLE=0
  CHECKS=$( grep '"entity_id":\|"check_id":\|"id:"\|"label":\|"disabled":\|"notification_plan_id":\|"criteria":' <<<"$CHECKS" |
    while read LINE; do
      if [[ "$LINE" =~ '"id":' ]]; then
        TEMPID=$( cut -d\" -f4 <<<"$LINE" )
      elif [[ "$LINE" =~ '"label":' ]]; then
        TEMPLBL=$( cut -d\" -f4 <<<"$LINE" )
      else
        TEMPDISABLED=$( grep -o 'true\|false' <<<"$LINE" )
      fi
      if [[ $TOGGLE -eq 6 ]]; then
        echo "\"$TEMPID\",\"$TEMPLBL\",\"$TEMPDISABLED\""
        TOGGLE=0
      else
        TOGGLE=$(( $TOGGLE + 1 ))
      fi
    done )

done

