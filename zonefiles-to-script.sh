#!/bin/bash

# Author: Andrew Howard
# Assumes a directory of zone files, where the filename is the domain
# outputs to stdout - you probably want to redirect this to a file


# Stuff we don't want
#cat * | sed 's/;.*$//' |
#  grep -ivE '\s\s*SOA\s\s*' |
#  grep -ivE '^\s*[0-9][0-9]*\s*\)?\s*$' |
#  grep -ivE '\s\s*NS\s\s*' |
#  grep -ivE '^\s*\$TTL\s' |
#  grep -ivE '\$include ' |
#  grep -ivE '^\s*$'

# Stuff I want
#cat * | sed 's/;.*$//' |
#  grep -ivE '\s\s*A\s\s*' | 
#  grep -ivE '\s\s*AAAA\s\s*' | 
#  grep -ivE '\s\s*CNAME\s\s*' | 
#  grep -ivE '\s\s*MX\s\s*' |
#  grep -ivE '\s\s*(TXT|SPF)\s\s*' |
#  grep -ivE '\s\s*SRV\s\s*' |



ACCT=825357
ZONEDIR=/home/ahoward/Downloads/tmp/


cd $ZONEDIR
ZONES=*


for ZONE in $ZONES; do
  #
  # Create the zone with default records
  echo "add_default_zone $ZONE $ACCT"

  #
  # A records
  grep -iE '\s\s*A\s\s*' $ZONE |
    sed 's/;.*$//' |
    sed "s/@/$ZONE./" |
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' )
      TARGET=$( echo "$LINE" | awk '{print $NF}' )
      echo "add_address_record $ZONE $RECORD $TARGET"
    done
  
  #
  # AAAA records
  grep -iE '\s\s*AAAA\s\s*' $ZONE | 
    sed 's/;.*$//' |
    sed "s/@/$ZONE./" |
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' )
      TARGET=$( echo "$LINE" | awk '{print $NF}' )
      echo "add_aaaa_record $ZONE $RECORD $TARGET"
    done
  
  #
  # CNAME records
  grep -iE '\s\s*CNAME\s\s*' $ZONE | 
    sed 's/;.*$//' |
    sed "s/@/$ZONE./" |
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' )
      TARGET=$( echo "$LINE" | awk '{print $NF}' )
      echo "add_cname_record $ZONE $RECORD $TARGET"
    done
  
  #
  # MX records
  grep -iE '\s\s*MX\s\s*' $ZONE | 
    sed 's/;.*$//' |
    sed "s/@/$ZONE./" |
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' )
      TARGET=$( echo "$LINE" | awk '{print $NF}' )
      PRIORITY=$( echo "$LINE" | awk '{print $(NF-1)}' )
      echo "add_mx_record $ZONE $RECORD $PRIORITY $TARGET"
    done
  
  #
  # TXT/SPF records
  grep -iE '\s\s*(TXT|SPF)\s\s*' $ZONE | 
    sed 's/;.*$//' |
    sed "s/@/$ZONE./" |
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' )
      TARGET=$( echo "$LINE" | sed 's/.*\s\(TXT\|SPF\)\s\s*\(.*\)\s*$/\2/i' )
      echo "add_txt_record $ZONE $RECORD $TARGET"
    done

  #
  # SRV records
  grep -iE '\s\s*SRV\s\s*' $ZONE | 
    sed 's/;.*$//' |
    sed "s/@/$ZONE./" |
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' | cut -d. -f3- )
      SERVICE=$( echo "$LINE" | awk '{print $1}' | cut -d. -f1 )
      PROTOCOL=$( echo "$LINE" | awk '{print $1}' | cut -d. -f2 )
      TARGET=$( echo "$LINE" | awk '{print $NF}' )
      PORT=$( echo "$LINE" | awk '{print $(NF-1)}' )
      WEIGHT=$( echo "$LINE" | awk '{print $(NF-2)}' )
      PRIORITY=$( echo "$LINE" | awk '{print $(NF-3)}' )
      echo "add_srv_record $ZONE $RECORD $TARGET $SERVICE $PROTOCOL $PORT $WEIGHT $PRIORITY"
    done

  #
  # Print a newline
  echo

done
