#!/bin/bash

# Author: Andrew Howard

#
# Increment a lowercase character string.
# a>b, z>aa, aa>ab, zz>aaa
function incAlpha() {
  local ALPHA="$1"
  local LEASTSIG=$( echo "$ALPHA" | sed 's/^.*\(.\)$/\1/' )
  local ELSE=$( echo "$ALPHA" | sed 's/^\(.*\).$/\1/' )
  if [ -z "$ALPHA" ]; then
    echo 'a'
  elif [ "$LEASTSIG" != "z" ]; then
    LEASTSIG=$( echo "$LEASTSIG" | tr 'a-z' 'b-z0' )
    echo "$ELSE$LEASTSIG"
  else
    local NEWELSE=$( incAlpha $ELSE )
    echo "${NEWELSE}a"
  fi
}

incAlpha $1
