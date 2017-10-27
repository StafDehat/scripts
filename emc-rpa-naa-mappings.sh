#!/bin/bash
# Author: Andrew Howard

# Purpose:
# This script prints Source-NAA to Destination-NAA mappings
#   for all LUNs being replicated via EMC Recoverpoint RPA.
# Uses the EMC REST API

# Built-in documentation at the API host:
# https://${ENDPOINT}/fapi/rest/5_1/recoverpoint.wadl

# Full NAA: A1:A2:A3:A4:B1:B2:B3:B4:B5:B6:C1:C2:C3:C4:C5:C6
# Note: NAA is printed in hexadecimal, but the REST API will report
#   the NAA in the 'naaUid' field, as a signed-char.
# As such, each of the 16x colon-separated chunks of the NAA (ie: A1)
#   represent a single byte.
# The first 4x bytes of the NAA will always be the same, since they're
#   basically a vendor ID, and the vendor is always EMC (that I've seen)
#   So, A1-A4 in the template above, will be 60:00:09:70.
# The next 6x bytes of the NAA indicate the serial number of the array
#   on which this volume exists.  Refer to B1-B6 above.
# The last 6x bytes are volume-specific.  Refer to C1-C6 above.

USERNAME=""
PASSWORD=""
TOKEN=$( echo -n "${USERNAME}:${PASSWORD}" | base64 )
ENDPOINT="10.x.x.x:7225"
RESTURI="/fapi/rest/5_1"

function uid2naa() {
  # Input example: [96,0,9,112,0,17,34,51,68,85,-103,-86,-69,-35,-18,-1]
  # Output example: 60:00:09:70:00:11:22:33:44:55:99:AA:BB:DD:EE:FF
  local uid
  local naa
  uid=$( tr -d '[]' <<<"${1}" | tr ',:' ' ' )
  naa=""
  for byte in ${uid}; do
    if [[ ${byte} -lt 0 ]]; then
      byte=$(( 256+${byte} ))
    fi
    byte=$(printf "%02x" ${byte})
    naa+="${byte}:"
  done
  sed 's/\(^:\|:$\)//g' <<<"${naa}"
}

function naa2uid() {
  # Input example: 60:00:09:70:00:11:22:33:44:55:99:AA:BB:DD:EE:FF
  # Output example: [96,0,9,112,0,17,34,51,68,85,-103,-86,-69,-35,-18,-1]
  local naa
  local uid
  naa="${1}"
  naa=$( grep -Po '[0-9A-Fa-f:]+' <<<"${naa}" | tr ':' ' ' )
  uid=""
  for byte in ${naa}; do
    byte=$( printf "%d" "0x${byte}" )
    if [[ ${byte} -ge 128 ]]; then
      byte=$(( ${byte}-256 ))
    fi
    uid+="${byte},"
  done
  uid=$( sed 's/\(^,\|,$\)//g' <<<"${uid}" )
  echo "[${uid}]"
}

#function getClusterMaps() {
#  # Use "clusters" to get an enumeration of all arraySerialNumbers,
#  #   and to tie a name/region to each array.
#  curlData=$( curl -sk https://${ENDPOINT}${RESTURI}/clusters \
#                -H "Authorization: Basic ${TOKEN}" )
#  # Note: We can't ever use 'jq' on this curlData, because cluster IDs are ints > 2^64-1
#  # [stafdehat@server ~]$ echo "${curlData}"
#  # {"clustersInformation":[{"clusterUID":{"id":4444444444444444444},"clusterName":"JohnDoe"},{"clusterUID":{"id":3333333333333333333},"clusterName":"JaneDoe"}]}
#  # [stafdehat@server ~]$ echo "${curlData}" | jq -c "."        ^^^                                                                ^^^
#  # {"clustersInformation":[{"clusterUID":{"id":4444444444444445000},"clusterName":"JohnDoe"},{"clusterUID":{"id":3333333333333334000},"clusterName":"JaneDoe"}]}
#  # [stafdehat@server ~]$                                       ^^^                                                                ^^^
#  clusters=$(
#    grep -Po '({\s*"clusterUID"\s*:\s*{\s*"id"\s*:\s*\d+\s*}|"clusterName"\s*:\s*"[^"]+")' <<<"${curlData}" |
#      sed '/clusterUID/s/[^0-9]*\([0-9]\+\).*/\1/' |
#      sed -e '/clusterName/s/^\([^"]*"\)\{3\}//' -e '/"/s/^/"/' |
#      paste -d"\t" - -
#  )
#  while read LINE; do
#    # Note: One field will be numeric, and the other won't.  The numeric one
#    #   is the clusterID, the non-numeric (quoted) one is the clusterName.
#    clusterId=$(   awk -F '\t' '$1 ~ /^[0-9]+$/ {print $1;next} {print $2}' <<<"${LINE}" )
#    clusterName=$( awk -F '\t' '$1 ~ /^[0-9]+$/ {print $2;next} {print $1}' <<<"${LINE}" | tr -d '"' )
#    curlData=$( curl -sk https://${ENDPOINT}${RESTURI}/clusters/${clusterId}/settings \
#                  -H "Authorization: Basic ${TOKEN}" )
#    arraySerialNumber=$( jq -r ".repositoryVolume.volumeInfo.arraySerialNumber" <<<"${curlData}" )
#    echo -e "${arraySerialNumber}\t${clusterId}\t${clusterName}"
#  done <<<"${clusters}"
#}


# Enumerate the "groups" (These are consistency groups)
curlData=$( curl -sk https://${ENDPOINT}${RESTURI}/groups \
              -H "Authorization: Basic ${TOKEN}" )
numGroups=$( jq -r ".innerSet|length" <<<"${curlData}" )
groupIds=$(
  for x in $( seq 0 $((numGroups-1)) ); do
    jq -r ".innerSet[$x].id" <<<"${curlData}"
  done
)


(
echo "--------- ---------- ----------------------------------------------- -----------------------------------------------"
echo "GroupName LunSize OneLUN TwoLUN"
#awk '{print $3}' <<<"${clusterMaps}" | sort | paste - -
echo "--------- ---------- ----------------------------------------------- -----------------------------------------------"
for groupId in ${groupIds}; do
  # Fetch the "name" of this group.  ie: AccountNum_DeviceNum
  curlData=$( curl -sk https://${ENDPOINT}${RESTURI}/groups/${groupId}/name \
                -H "Authorization: Basic ${TOKEN}" )
  groupName=$( jq -r ".string" <<<"${curlData}" | tr -d ' ' )

  echo "Enumerating LUNs for Consistency Group '${groupName}'" >&2

  # Fetch info on all replication_sets associated with this group
  # Every replication set should have 2x LUNs (ie: volumes) - a SRC & DST
  curlData=$( curl -sk https://${ENDPOINT}${RESTURI}/groups/${groupId}/replication_sets \
                -H "Authorization: Basic ${TOKEN}" )
  rSetsJson="${curlData}"
  numRSets=$( jq -r ".innerSet|length" <<<"${rSetsJson}" )

  # Each iteration of this loop handles reporting for a single replication set (repl-pair)
  for i in $( seq 0 $((numRSets-1)) ); do
    rSetId=$(   jq -r ".innerSet[${i}].replicationSetUID.id" <<<"${rSetsJson}" )
    rSetName=$( jq -r ".innerSet[${i}].replicationSetName"   <<<"${rSetsJson}" )
    rSetSize=$( jq -r ".innerSet[${i}].sizeInBytes"          <<<"${rSetsJson}" )
    numVols=$(  jq -r ".innerSet[${i}].volumes|length"       <<<"${rSetsJson}" )
    if [[ "${numVols}" -ne 2 ]]; then
      echo "Unexpected issue - replication set contains !=2 volumes.  Skipping this one."
      continue
    fi

    echo -n "${groupName} ${rSetSize} "

    # Each iteration of this loop handles reporting for 1 of the LUNs in the replication set
    # Wishlist: Somehow, determine which of these two is the SRC & which is the DST
    for j in $( seq 0 $((numVols-1)) ); do
      arraySerialNumber=$( jq -r ".innerSet[${i}].volumes[${j}].volumeInfo.arraySerialNumber" <<<"${rSetsJson}" )
      volName=$( jq -r ".innerSet[${i}].volumes[${j}].volumeInfo.volumeName" <<<"${rSetsJson}" )
      volUid=$( jq -r ".innerSet[${i}].volumes[${j}].volumeInfo.naaUid" <<<"${rSetsJson}" )
      volNaa=$( uid2naa "${volUid}" )
      #clusterName=$( awk '$1 == '${arraySerialNumber}' {print $3}' <<<"${clusterMaps}" )
      echo "${volNaa}"
    done | paste - -
  done
done
echo "--------- ---------- ----------------------------------------------- -----------------------------------------------"
) | column -t


