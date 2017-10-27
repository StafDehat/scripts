#!/bin/bash
# Author: Andrew Howard

# Note: NAA is stored as 16 bytes.  In the EMC REST API, it shows you
#   those 16 bytes as a list/array of 16x signed chars, displayed in
#   decimal.  In the EMC GUI, it shows you the NAA as 16x colon-
#   separated 1-byte hex numbers (00-FF).

function uid2naa() {
  # Input example: [96,0,9,112,0,1,-107,112,20,52,83,48,50,53,48,52]
  # Output example: 60:00:09:70:00:01:95:70:14:34:53:30:32:35:30:34
  local uid
  local naa
  uid="${1}"
  uid=$( tr -d '[]' <<<"${uid}" | tr ',:' ' ' )
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
  # Input example: 60:00:09:70:00:01:95:70:14:34:53:30:32:35:30:34
  # Output example: [96,0,9,112,0,1,-107,112,20,52,83,48,50,53,48,52]
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

