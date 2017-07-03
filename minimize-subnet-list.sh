#!/bin/bash

# Author: Andrew Howard

function NTOA() {
  N=$1
  # AMASK=16777216
  # BMASK=65536
  # CMASK=256
  AQUAD=$( echo $N | cut -d\. -f1 )
  BQUAD=$( echo $N | cut -d\. -f2 )
  CQUAD=$( echo $N | cut -d\. -f3 )
  DQUAD=$( echo $N | cut -d\. -f4 )
  A=$DQUAD
  A=$(( A + CQUAD * 256 ))
  A=$(( A + BQUAD * 65536 ))
  A=$(( A + AQUAD * 16777216 ))
  echo "${A}"
}

function ATON() {
  A="${1}"
  if [[ ! "${A}" =~ ^[0-9]+$ ||
          "${A}" -gt 4294967295 ]]; then
    echo "0.0.0.0" && return 1
  fi
  # AMASK=16777216
  # BMASK=65536
  # CMASK=256
  AQUAD=$(( A / 16777216 ))
  BQUAD=$(( ( A % 16777216 ) / 65536 ))
  CQUAD=$(( ( A % 65536 ) / 256 ))
  DQUAD=$(( A % 256 ))
  echo "$AQUAD.$BQUAD.$CQUAD.$DQUAD"
}

function toARange() {
  LINE="${@}"
  ADDR=$( echo "${LINE}" | cut -d/ -f1 )
  CIDR=$( echo "${LINE}" | cut -d/ -f2 )
  RMASK="${CIDR}"
  LMASK=$(( 32 - RMASK ))
  A=$(NTOA "${ADDR}")
  SIZE=$(( 2**LMASK ))
  LOA="${A}"
  HIA="$(( A + SIZE - 1 ))"
  #LON=$( ATON ${LOA} )
  #HIN=$( ATON ${HIA} )
  echo "${LOA} ${HIA}"
}


AllARanges=$(
  while read LINE; do
    toARange "${LINE}"
  done | sort -n
)

OLDLO=0
OLDHI=0
MinARanges=$( 
  while read LOA HIA; do
    if [[ ${OLDHI} -eq 0 ]]; then
      OLDLO=${LOA}
      OLDHI=${HIA}
      continue
    elif [[ $(( OLDHI+1 )) -eq ${LOA} ]]; then
      OLDHI=${HIA}
    else
      echo "${OLDLO} ${OLDHI}"
      OLDLO=${LOA}
      OLDHI=${HIA}
    fi
  done <<<"${AllARanges}"
  echo "${OLDLO} ${OLDHI}"
)

while read LOA HIA; do
  LON=$( ATON ${LOA} )
  HIN=$( ATON ${HIA} )
  echo "${LON},${HIN}"
done <<<"${MinARanges}"

