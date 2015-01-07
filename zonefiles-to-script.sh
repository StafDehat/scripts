#!/bin/bash

# Author: Andrew Howard

# Known limitations:
# Requires perl-regexp support for grep (-P), otherwise Windows-style
#   newlines would cause issues.
# Only handles A, AAAA, CNAME, MX, PTR, SRV, and TXT/SPF records,
#   because ScriptRunner doesn't handle anything else.
# Custom TTLs are ignored
# Currently does not handle 'origin' syntax at all.  This is a huge
#   failing of this script, but will rarely come into play.


# These two variables need to be set:
ACCT=123456
ZONEDIR=/home/ahoward/Downloads/tmp/root/dnsexport

# ACCT should be the account number into which these zones are being imported
# ZONEDIR should be a directory containing *only* bind9-format zone files,
#   and those files should have the same name as the zone itself (ie: @).


cd $ZONEDIR
ZONES=*


#
# Attempt to create the zones on ACCT
for ZONE in $ZONES; do
  echo "add_default_zone $ZONE $ACCT"
done
echo


for ZONE in $ZONES; do
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
  grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?PTR\s+' $ZONE |
    sed -e 's/\s*\(;.*\)\?$//' |
    sed '/^\s*$/d' | # Delete empty lines
    sort -n |
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' )
      if [ -z "$RECORD" ]; then
        continue  # Totally not okay
      elif grep -qP '\.$' <<<"$RECORD"; then
        # ie: 155.0.16.10.in-addr.arpa.
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        # ie: 155
        RECORD="$RECORD.$ZONE"
      fi
      RECORD=$( echo "$RECORD" | sed 's/\.in-addr\.arpa.*//' |
                  tr '.' '\n' | tac | tr '\n' '.' | sed 's/\.\s*$//' )
      TARGET=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $NF}' )
      if grep -qP '\.$' <<<"$TARGET"; then
        TARGET=$( echo "$TARGET" | sed 's/\.$//' )
      else
        TARGET="$TARGET.$ZONE"
      fi
      echo "add_ptr_record $ZONE $RECORD $TARGET"
    done

  #
  # Print a newline
  echo

done
