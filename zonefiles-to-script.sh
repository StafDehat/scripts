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


function usage() {
  echo
  echo "Description:"
  echo "  Generate ScriptRunner syntax to recreate on ACCOUNT, using DNS"
  echo "  Tool ScriptRunner syntax,  all zone files stored in DIRECTORY."
  echo ""
  echo "Usage: zonefiles-to-script.sh -a ACCOUNT \\"
  echo "                              -d DIRECTORY \\"
  echo "                              [-h] [-r] [-z]"
  echo "Example: ./zonefiles-to-script.sh -a 123456 \\"
  echo "                                  -d /tmp/zones \\"
  echo "                                  -z"
  echo ""
  echo "Arguments:"
  echo "  -a X  Customer's account number (or DDI)."
  echo "  -d X  Directory containing zone files (and only zone files)."
  echo "  -h    Print this help."
  echo "  -r    Generate script commands to recreate records.  Assume"
  echo "        prior existence of zones."
  echo "  -z    Generate script commands to create empty zones."
}

USAGEFLAG=0
ACCT=""
DORECORDS=0
DOZONES=0
ZONEDIR=""
while getopts ":a:d:hrz" arg; do
  case $arg in
    a) ACCT=$OPTARG;;
    d) ZONEDIR=$OPTARG;;
    h) usage && exit 0;;
    r) DORECORDS=1;;
    z) DOZONES=1;;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done

if [ -z "$ZONEDIR" ]; then
  echo "ERROR: Must define DIRECTORY as argument (-d)"
  USAGEFLAG=1
elif [ ! -d "$ZONEDIR" ]; then
  echo "ERROR: Specified directory does not exist or is not accessible."
  USAGEFLAG=1
fi

if [ -z "$ACCT" ]; then
  echo "ERROR: Must define ACCOUNT as argument (-a)"
  USAGEFLAG=1
elif [ $( grep -cE '^[0-9][0-9]*$' <<<"$ACCT" ) -ne 1 ]; then
  echo "ERROR: Specified accout must be numeric."
  USAGEFLAG=1
fi
if [ $USAGEFLAG -ne 0 ]; then
  usage && exit 1
fi


#
# This gets run if argument $1 was '1'
function addzones() {
  #
  # Attempt to create the zones on ACCT
  NUMZONES=0
  for ZONE in $ZONES; do
    echo "add_default_zone $ZONE $ACCT"
    NUMZONES=$(( $NUMZONES + 1 ))
  done
  echo
  #
  # Record in appstats that this was executed.
  ( curl -s https://appstats.rackspace.com/appstats/event/ \
         -X POST \
         -H "Content-Type: application/json" \
         -d '{ "username": "andrew.howard",
               "status": "SUCCESS",
               "bizunit": "Enterprise",
               "OS": "Linux",
               "functionid": "Part1-Zones",
               "source": "https://github.com/StafDehat/scripts/blob/master/zonefiles-to-script.sh",
               "version": "1.0",
               "appid": "zonefiles-to-script.sh",
               "device": "N/A",
               "ip": "",
               "datey": "'$(date +%Y)'",
               "datem": "'$(date +%-m)'",
               "dated": "'$(date +%-d)'",
               "dateh": "'$(date +%-H)'",
               "datemin": "'$(date +%-M)'",
               "dates": "'$(date +%-S)'"
               }' &) &>/dev/null
  #
  # Report usage stats to author's tracking tool
  (curl -k "https://stats.rootmypc.net/dnsstats.php?zones=$NUMZONES&records=0" &) &>/dev/null
}

#
# This gets run if argument $1 was '2'
function addrecords() {
  NUMRECORDS=0
  for ZONE in $ZONES; do
    #
    # A records
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' | sed 's/\s*$//' )
      if grep -qP '\.$' <<<$RECORD; then
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        RECORD="$RECORD.$ZONE"
      fi
      TARGET=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $NF}' )
      echo "add_address_record $ZONE $RECORD $TARGET"
      NUMRECORDS=$(( $NUMRECORDS + 1 ))
    done < <( grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?A\s+' $ZONE |
                sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
                sed '/^\s*$/d' )
    
    #
    # AAAA records
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' | sed 's/\s*$//' )
      if grep -qP '\.$' <<<"$RECORD"; then
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        RECORD="$RECORD.$ZONE"
      fi
      TARGET=$( echo "$LINE" | sed 's/\s*$//' | awk '{print $NF}' )
      echo "add_aaaa_record $ZONE $RECORD $TARGET"
      NUMRECORDS=$(( $NUMRECORDS + 1 ))
    done < <( grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?AAAA\s+' $ZONE |
                sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
                sed '/^\s*$/d' )
    
    #
    # CNAME records
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
      NUMRECORDS=$(( $NUMRECORDS + 1 ))
    done < <( grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?CNAME\s+' $ZONE |
                sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
                sed '/^\s*$/d' )
    
    #
    # MX records
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
      NUMRECORDS=$(( $NUMRECORDS + 1 ))
    done < <( grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?MX\s+\d+\s+' $ZONE |
                  sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
                  sed '/^\s*$/d' )
    
    #
    # TXT/SPF records
    while read LINE; do
      RECORD=$( echo "$LINE" | awk '{print $1}' )
      if grep -qP '\.$' <<<"$RECORD"; then
        RECORD=$( echo "$RECORD" | sed 's/\.$//' )
      else
        RECORD="$RECORD.$ZONE"
      fi
      TARGET=$( echo "$LINE" | sed 's/.*\s\(TXT\|SPF\)\s\s*\(.*\)\s*$/\2/i' )
      echo "add_txt_record $ZONE $RECORD $TARGET"
      NUMRECORDS=$(( $NUMRECORDS + 1 ))
    done < <( grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?(TXT|SPF)\s+' $ZONE |
                  sed "s/^\(\([^\"';]*|\"[^\"]*\"\|'[^']*'\)*\);.*$/\1/" | # Scrub trailing comments
                  sed "s/@/$ZONE./" | # Sub out @ for the zone name
                  sed '/^\s*$/d' )
  
    #
    # SRV records
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
      NUMRECORDS=$(( $NUMRECORDS + 1 ))
    done < <( grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?SRV\s+\d+\s+\d+\s+\d+\s+' $ZONE |
                  sed -e 's/\s*\(;.*\)\?$//' -e "s/@/$ZONE./" |
                  sed '/^\s*$/d' )
  
    #
    # PTR records
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
      NUMRECORDS=$(( $NUMRECORDS + 1 ))
    done < <( grep -iP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?PTR\s+' $ZONE |
                sed -e 's/\s*\(;.*\)\?$//' |
                sed '/^\s*$/d' | # Delete empty lines
                sort -n )
  
    #
    # Print a newline
    echo
  
  done

  #
  # Record in appstats that this was executed.
  ( curl -s https://appstats.rackspace.com/appstats/event/ \
         -X POST \
         -H "Content-Type: application/json" \
         -d '{ "username": "andrew.howard",
               "status": "SUCCESS",
               "bizunit": "Enterprise",
               "OS": "Linux",
               "functionid": "Part2-Records",
               "source": "https://github.com/StafDehat/scripts/blob/master/zonefiles-to-script.sh",
               "version": "1.0",
               "appid": "zonefiles-to-script.sh",
               "device": "N/A",
               "ip": "",
               "datey": "'$(date +%Y)'",
               "datem": "'$(date +%-m)'",
               "dated": "'$(date +%-d)'",
               "dateh": "'$(date +%-H)'",
               "datemin": "'$(date +%-M)'",
               "dates": "'$(date +%-S)'"
               }' &) &>/dev/null
  #
  # Report usage stats to author's tracking tool
  (curl -k "https://stats.rootmypc.net/dnsstats.php?zones=0&records=$NUMRECORDS" &) &>/dev/null
}



cd $ZONEDIR
# Do at least a tiny bit of verification to see if these files are, in fact, DNS zones
ZONES=$( grep -li soa * )

if [ $DOZONES -eq 1 ]; then
  addzones
fi
if [ $DORECORDS -eq 1 ]; then
  addrecords
fi
