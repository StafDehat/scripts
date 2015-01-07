#!/bin/bash

# Author: Andrew Howard
# Assumes a directory of zone files, where the filename is the domain
# outputs to stdout - you probably want to redirect this to a file

# Known limitations:
# Currently does not handle 'origin' syntax at all.  This is a huge
#   failing of this script, but will rarely come into play.
# Ignores NS records.  This is due to ScriptRunner limitations, and
#   also because they're unlikely to be accurate anyway.
# Ignores PTR records.
# Custom TTLs are ignored
# Requires perl-regexp support for grep (-P), otherwise Windows-style
#   newlines would cause issues.

# Stuff we don't want
#cat * | sed 's/;.*$//' |
#  grep -ivP '\s\s*SOA\s\s*' |
#  grep -ivP '^\s*[0-9][0-9]*\s*\)?\s*$' |
#  grep -ivP '\s\s*NS\s\s*' |
#  grep -ivP '^\s*\$TTL\s' |
#  grep -ivP '\$include ' |
#  grep -ivP '^\s*$'

# Stuff I want
#cat * | sed 's/;.*$//' |
#  grep -ivP '\s\s*A\s\s*' | 
#  grep -ivP '\s\s*AAAA\s\s*' | 
#  grep -ivP '\s\s*CNAME\s\s*' | 
#  grep -ivP '\s\s*MX\s\s*' |
#  grep -ivP '\s\s*(TXT SPF)\s\s*' |
#  grep -ivP '\s\s*SRV\s\s*' |



ACCT=123456
ZONEDIR=/home/ahoward/Downloads/tmp/root/dnsexport


cd $ZONEDIR
ZONES=*


for ZONE in $ZONES; do
  #
  # Create the zone with default records
  echo "add_default_zone $ZONE $ACCT"

  #
  # A records
  grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?A\s+' $ZONE |
    sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
    sed '/^\s*$/d' | # Delete empty lines
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' | sed 's/\s*$//' )
      if grep -qP '\.$' <<<$RECORD; then
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        RECORD="$RECORD.$ZONE"
      fi
      TARGET=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $NF}' )
      echo "add_address_record $ZONE $RECORD $TARGET"
    done
  
  #
  # AAAA records
  grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?AAAA\s+' $ZONE |
    sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
    sed '/^\s*$/d' | # Delete empty lines
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' | sed 's/\s*$//' )
      if grep -qP '\.$' <<<"$RECORD"; then
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        RECORD="$RECORD.$ZONE"
      fi
      TARGET=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $NF}' )
      echo "add_aaaa_record $ZONE $RECORD $TARGET"
    done
  
  #
  # CNAME records
  grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?CNAME\s+' $ZONE |
    sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
    sed '/^\s*$/d' | # Delete empty lines
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' | sed 's/\s*$//' )
      if grep -qP '\.$' <<<"$RECORD"; then
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        RECORD="$RECORD.$ZONE"
      fi
      TARGET=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $NF}' )
      if grep -qP '\.$' <<<"$TARGET"; then
        TARGET=$( echo "$TARGET" | sed 's/\.$//' )
      else
        TARGET="$TARGET.$ZONE"
      fi
      echo "add_cname_record $ZONE $RECORD $TARGET"
    done
  
  #
  # MX records
  grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?MX\s+\d+\s+' $ZONE |
    sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
    sed '/^\s*$/d' | # Delete empty lines
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' | sed 's/\s*$//' )
      if grep -qP '\.$' <<<"$RECORD"; then
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        RECORD="$RECORD.$ZONE"
      fi
      TARGET=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $NF}' )
      if grep -qP '\.$' <<<"$TARGET"; then
        TARGET=$( echo "$TARGET" | sed 's/\.$//' )
      else
        TARGET="$TARGET.$ZONE"
      fi
      PRIORITY=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $(NF-1)}' )
      echo "add_mx_record $ZONE $RECORD $PRIORITY $TARGET"
    done
  
  #
  # TXT/SPF records
  grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?(TXT|SPF)\s+' $ZONE |
    sed "s/^\(\([^\"';]*|\"[^\"]*\"\|'[^']*'\)*\);.*$/\1/" | # Scrub trailing comments
    sed "s/@/$ZONE./" | # Sub out @ for the zone name
    sed '/^\s*$/d' | # Delete empty lines
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' )
      if grep -qP '\.$' <<<"$RECORD"; then
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        RECORD="$RECORD.$ZONE"
      fi
      TARGET=$( echo "$LINE" | sed 's/.*\s\(TXT\|SPF\)\s\s*\(.*\)\s*$/\2/i' )
      echo "add_txt_record $ZONE $RECORD $TARGET"
    done

  #
  # SRV records
  grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?SRV\s+\d+\s+\d+\s+\d+\s+' $ZONE |
    sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
    sed '/^\s*$/d' | # Delete empty lines
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' | cut -d. -f3- )
      if [ -z "$RECORD" ]; then
        RECORD="$ZONE"
      elif grep -qP '\.$' <<<"$RECORD"; then
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        RECORD="$RECORD.$ZONE"
      fi
      SERVICE=$( echo "$LINE" | awk '{print $1}' | cut -d. -f1 )
      PROTOCOL=$( echo "$LINE" | awk '{print $1}' | cut -d. -f2 )
      TARGET=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $NF}' )
      if grep -qP '\.$' <<<"$TARGET"; then
        TARGET=$( echo "$TARGET" | sed 's/\.$//' )
      else
        TARGET="$TARGET.$ZONE"
      fi
      PORT=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $(NF-1)}' )
      WEIGHT=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $(NF-2)}' )
      PRIORITY=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $(NF-3)}' )
      echo "add_srv_record $ZONE $RECORD $TARGET $SERVICE $PROTOCOL $PORT $WEIGHT $PRIORITY"
    done

  #
  # PTR records
#  cut -d\" -f1 $ZONE |
#    grep -iP '\s\s*MX\s\s*' |
#    sed 's/;.*$//' |
#    sed '/^\s*$/d' |
#    sed "s/@/$ZONE./"
#  add_ptr_record zone ip_address fqdn 


  #
  # Print a newline
  echo

done
