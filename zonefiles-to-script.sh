#!/bin/bash

# Author: Andrew Howard

# Known limitations:
# Requires perl-regexp support for grep (-P), otherwise Windows-style
#   newlines would cause issues.
# Only handles A, AAAA, CNAME, MX, PTR, SRV, and TXT/SPF records,
#   because ScriptRunner doesn't handle anything else.
# Custom TTLs are ignored

# "$ORIGIN values must be 'qualified' (they end with a 'dot')."
# http://www.zytrax.com/books/dns/ch8/origin.html

# Note: Still need to account for blank substitution:
# http://www.zytrax.com/books/dns/apa/origin.html

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

function addrecords() {
  NUMRECORDS=0
  for ZONE in $ZONES; do
    echo

    # ORIGIN initializes to the zonefile name
    ORIGIN="${ZONE}"

    # Parse file line-by-line
    while read LINE; do
      # If it's an ORIGIN line, redefine ORIGIN.  ZONE stays the same.
      if grep -qP '^\s*\$ORIGIN\s' <<<"${LINE}"; then
        ORIGIN="$( sed 's/;.*//' <<<"${LINE}" |
                     awk '{print $2}' |
                     sed 's/\.$//' )"
        continue
      fi

      #
      # A record
      if grep -qiP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?A\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        # Substitute '@' with the ORIGIN.  We want FQDNs.
        LINE=$( sed "s/@/$ORIGIN./" <<<"${LINE}" )
        RECORD=$( awk '{print $1}' <<<"${LINE}" ) # Warning: Fails if using blank substitution
        if grep -qP '\.$' <<<"${RECORD}"; then
          RECORD=$( sed 's/\.$//' <<<"${RECORD}" )
        else
          RECORD="$RECORD.$ORIGIN"
        fi
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        echo "add_address_record $ZONE $RECORD $TARGET"
        NUMRECORDS=$(( $NUMRECORDS + 1 ))
        continue
      fi
 
      #
      # AAAA record
      if grep -qiP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?AAAA\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        # Substitute '@' with the ORIGIN.  We want FQDNs.
        LINE=$( sed "s/@/$ORIGIN./" <<<"${LINE}" )
        RECORD=$( awk '{print $1}' <<<"${LINE}" ) # Warning: Fails if using blank substitution
        if grep -qP '\.$' <<<"${RECORD}"; then
          RECORD=$( sed 's/\.$//' <<<"${RECORD}" )
        else
          RECORD="$RECORD.$ORIGIN"
        fi
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        echo "add_aaaa_record $ZONE $RECORD $TARGET"
        NUMRECORDS=$(( $NUMRECORDS + 1 ))
        continue
      fi

      #
      # CNAME records
      if grep -qiP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?CNAME\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        # Substitute '@' with the ORIGIN.  We want FQDNs.
        LINE=$( sed "s/@/$ORIGIN./" <<<"${LINE}" )
        RECORD=$( awk '{print $1}' <<<"${LINE}" ) # Warning: Fails if using blank substitution
        if grep -qP '\.$' <<<"${RECORD}"; then
          RECORD=$( sed 's/\.$//' <<<"${RECORD}" )
        else
          RECORD="$RECORD.$ORIGIN"
        fi
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        if grep -qP '\.$' <<<"${TARGET}"; then
          TARGET=$( sed 's/\.$//' <<<"${TARGET}" )
        else
          TARGET="${TARGET}.${ORIGIN}"
        fi
        echo "add_cname_record $ZONE $RECORD $TARGET"
        NUMRECORDS=$(( $NUMRECORDS + 1 ))
        continue
      fi

      # 
      # MX records
      if grep -qiP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?MX\s+\d+\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        # Substitute '@' with the ORIGIN.  We want FQDNs.
        LINE=$( sed "s/@/$ORIGIN./" <<<"${LINE}" )
        RECORD=$( awk '{print $1}' <<<"${LINE}" ) # Warning: Fails if using blank substitution
        if grep -qP '\.$' <<<"${RECORD}"; then
          RECORD=$( sed 's/\.$//' <<<"${RECORD}" )
        else
          RECORD="$RECORD.$ORIGIN"
        fi
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        if grep -qP '\.$' <<<"${TARGET}"; then
          TARGET=$( sed 's/\.$//' <<<"${TARGET}" )
        else
          TARGET="${TARGET}.${ORIGIN}"
        fi
        PRIORITY=$( awk '{print $(NF-1)}' <<<"${LINE}" )
        echo "add_mx_record $ZONE $RECORD $PRIORITY $TARGET"
        NUMRECORDS=$(( $NUMRECORDS + 1 ))
        continue
      fi

      #
      # TXT/SPF records
      if grep -qiP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?(TXT|SPF)\s+' <<<"${LINE}"; then
        # Strip trailing comments - this is trickier than normal, 'cause ';'
        #   inside quotes doesn't mean comment - only outside quotes.
        LINE=$( sed "s/^\(\([^\"';]*|\"[^\"]*\"\|'[^']*'\)*\);.*$/\1/" <<<"${LINE}" )
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        LINE=$( sed 's/\s*$//' <<<"${LINE}" ) # Strip trailing whitespace
        # This sed is a beast, but what it's doing, is to replace all '@' with the ORIGIN,
        #   but only when that '@' symbol is *not* inside quotes.
        LINE=$( sed ":loop; s/^\(\([^\"'@]*\)\?\(\"[^\"]*\"\)\?\('[^']*'\)\?\)*@/\1${ORIGIN}./g; t loop" <<<"${LINE}" )
        RECORD=$( awk '{print $1}' <<<"${LINE}" ) # Warning: Fails if using blank substitution
        if grep -qP '\.$' <<<"${RECORD}"; then
          RECORD=$( sed 's/\.$//' <<<"${RECORD}" )
        else
          RECORD="${RECORD}.${ORIGIN}"
        fi
        TARGET=$( sed 's/.*\s\(TXT\|SPF\)\s\s*\(.*\)\s*$/\2/i' <<<"${LINE}" )
        echo "add_txt_record ${ZONE} ${RECORD} ${TARGET}"
        NUMRECORDS=$(( ${NUMRECORDS} + 1 ))
        continue
      fi

      #
      # SRV records
      if grep -qiP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?SRV\s+\d+\s+\d+\s+\d+\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          continue # If that leaves us with a blank line, just skip to the next line.
        fi
        # Substitute '@' with the ORIGIN.  We want FQDNs.
        LINE=$( sed "s/@/$ORIGIN./" <<<"${LINE}" )
        RECORD=$( awk '{print $1}' <<<"${LINE}" | cut -d. -f3- ) # Warning: Fails if using blank substitution
        if [[ -z "${RECORD}" ]]; then
          RECORD="${ORIGIN}"
        elif grep -qP '\.$' <<<"${RECORD}"; then
          RECORD=$( sed 's/\.$//' <<<"${RECORD}" )
        else
          RECORD="${RECORD}.${ORIGIN}"
        fi
        SERVICE=$( awk '{print $1}' <<<"${LINE}" | cut -d. -f1 )
        PROTOCOL=$( awk '{print $1}' <<<"${LINE}" | cut -d. -f2 )
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        if grep -qP '\.$' <<<"${TARGET}"; then
          TARGET=$( sed 's/\.$//' <<<"${TARGET}" )
        else
          TARGET="${TARGET}.${ORIGIN}"
        fi
        PORT=$( awk '{print $(NF-1)}' <<<"${LINE}" )
        WEIGHT=$( awk '{print $(NF-2)}' <<<"${LINE}" )
        PRIORITY=$( awk '{print $(NF-3)}' <<<"${LINE}" )
        echo "add_srv_record ${ZONE} ${RECORD} ${TARGET} ${SERVICE} ${PROTOCOL} ${PORT} ${WEIGHT} ${PRIORITY}"
        NUMRECORDS=$(( ${NUMRECORDS} + 1 ))
        continue
      fi

      #
      # PTR records
      if grep -qiP '^\s*[^\s]+\s+(\d+[^\s]*\s+)?(IN\s+)?PTR\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          continue # If that leaves us with a blank line, just skip to the next line.
        fi
        # Substitute '@' with the ORIGIN.  We want FQDNs.
        LINE=$( sed "s/@/$ORIGIN./" <<<"${LINE}" )
        RECORD=$( awk '{print $1}' <<<"${LINE}" )
        if [ -z "$RECORD" ]; then
          continue  # Totally not okay
        elif grep -qP '\.$' <<<"$RECORD"; then
          # ie: 155.0.16.10.in-addr.arpa.
          RECORD=$( sed 's/\.$//' <<<"${RECORD}" )
        else # ie: 155
          RECORD="${RECORD}.${ORIGIN}"
        fi
        RECORD=$( sed 's/\.in-addr\.arpa.*//' <<<"${RECORD}" |
                    tr '.' '\n' | tac | tr '\n' '.' | sed 's/\.\s*$//' )
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        if grep -qP '\.$' <<<"${TARGET}"; then
          TARGET=$( sed 's/\.$//' <<<"${TARGET}" )
        else
          TARGET="${TARGET}.${ORIGIN}"
        fi
        echo "add_ptr_record ${ZONE} ${RECORD} ${TARGET}"
        NUMRECORDS=$(( $NUMRECORDS + 1 ))
        continue
      fi
    done < "${ZONE}" #End LINE loop
  done #End ZONE loop

  #
  # Record in appstats that this was executed.
  #( curl -s https://appstats.rackspace.com/appstats/event/ \
  #       -X POST \
  #       -H "Content-Type: application/json" \
  #       -d '{ "username": "andrew.howard",
  #             "status": "SUCCESS",
  #             "bizunit": "Enterprise",
  #             "OS": "Linux",
  #             "functionid": "Part2-Records",
  #             "source": "https://github.com/StafDehat/scripts/blob/master/zonefiles-to-script.sh",
  #             "version": "1.0",
  #             "appid": "zonefiles-to-script.sh",
  #             "device": "N/A",
  #             "ip": "",
  #             "datey": "'$(date +%Y)'",
  #             "datem": "'$(date +%-m)'",
  #             "dated": "'$(date +%-d)'",
  #             "dateh": "'$(date +%-H)'",
  #             "datemin": "'$(date +%-M)'",
  #             "dates": "'$(date +%-S)'"
  #             }' &) &>/dev/null
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
