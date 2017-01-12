#!/bin/bash

# Author: Andrew Howard

# Known limitations:
# Requires perl-regexp support for grep (-P), otherwise Windows-style
#   newlines would cause issues.
# Only handles A, AAAA, CNAME, MX, PTR, SRV, and TXT/SPF records,
#   because ScriptRunner doesn't handle anything else.
# Custom TTLs are ignored

# "$ORIGIN values must be 'qualified' (they end with a 'dot')."
# That's why I'm not runnin' 'em through qualifyName()
# http://www.zytrax.com/books/dns/ch8/origin.html

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
elif [ $( grep -cP '^\d+$' <<<"$ACCT" ) -ne 1 ]; then
  echo "ERROR: Specified accout must be numeric."
  USAGEFLAG=1
fi
if [ $USAGEFLAG -ne 0 ]; then
  usage && exit 1
fi


# Convert a possibly-unqualified, bind9-format name into a FQDN.
# Strip the trailing '.' too, since DNS Tool doesn't want those.
function qualifyName() {
  local NAME="${1}"
  local ORIGIN="${2}"
  # Swap '@' for ORIGIN, if it appears
  NAME=$( sed 's/@/'"${ORIGIN}"'./' <<<"${NAME}" )
  # Test for unqualified names
  if grep -qP '\.$' <<<"${NAME}"; then
    # Qualified - just strip the '.'
    NAME=$( sed 's/\.$//' <<<"${NAME}" )
  else
    # Unqualified - append ORIGIN
    NAME="${NAME}.${ORIGIN}"
  fi
  echo "${NAME}"
}

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
    # Initialize LASTRECORD, for use with blank substitution:
    # http://www.zytrax.com/books/dns/apa/origin.html
    LASTRECORD=""

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
      if grep -qiP '^\s*([a-z\-\d\.]+\s+)?(\d+[a-z]?\s+)?IN\s+A\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        # Test to see if they used "blank substitution"
        if grep -qiP '^\s+(\d+[a-z]?\s+)?IN\s+A\s+' <<<"${LINE}"; then
          if [[ -n "${LASTRECORD}" ]]; then
            RECORD="${LASTRECORD}"
          else
            RECORD="${ORIGIN}"
          fi
        else
          RECORD=$( awk '{print $1}' <<<"${LINE}" )
          RECORD=$( qualifyName "${RECORD}" "${ORIGIN}" )
          LASTRECORD="${RECORD}"
        fi
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        echo "add_address_record $ZONE $RECORD $TARGET"
        NUMRECORDS=$(( $NUMRECORDS + 1 ))
        continue
      fi
 
      #
      # AAAA record
      if grep -qiP '^\s*([a-z\-\d\.]+\s+)?(\d+[a-z]?\s+)?IN\s+AAAA\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        # Test to see if they used "blank substitution"
        if grep -qiP '^\s+(\d+[a-z]?\s+)?IN\s+AAAA\s+' <<<"${LINE}"; then
          if [[ -n "${LASTRECORD}" ]]; then
            RECORD="${LASTRECORD}"
          else
            RECORD="${ORIGIN}"
          fi
        else
          RECORD=$( awk '{print $1}' <<<"${LINE}" )
          RECORD=$( qualifyName "${RECORD}" "${ORIGIN}" )
          LASTRECORD="${RECORD}"
        fi
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        echo "add_aaaa_record $ZONE $RECORD $TARGET"
        NUMRECORDS=$(( $NUMRECORDS + 1 ))
        continue
      fi

      #
      # CNAME records
      if grep -qiP '^\s*([a-z\-\d\.]+\s+)?(\d+[a-z]?\s+)?IN\s+CNAME\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        # Test to see if they used "blank substitution"
        if grep -qiP '^\s+(\d+[a-z]?\s+)?IN\s+CNAME\s+' <<<"${LINE}"; then
          if [[ -n "${LASTRECORD}" ]]; then
            RECORD="${LASTRECORD}"
          else
            RECORD="${ORIGIN}"
          fi
        else
          RECORD=$( awk '{print $1}' <<<"${LINE}" )
          RECORD=$( qualifyName "${RECORD}" "${ORIGIN}" )
          LASTRECORD="${RECORD}"
        fi
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        TARGET=$( qualifyName "${TARGET}" "${ORIGIN}" )
        echo "add_cname_record $ZONE $RECORD $TARGET"
        NUMRECORDS=$(( $NUMRECORDS + 1 ))
        continue
      fi

      # 
      # MX records
      if grep -qiP '^\s*([a-z\-\d\.]+\s+)?(\d+[a-z]?\s+)?IN\s+MX\s+\d+\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        # Test to see if they used "blank substitution"
        if grep -qiP '^\s+(\d+[a-z]?\s+)?IN\s+MX\s+\d+\s+' <<<"${LINE}"; then
          # No explicit name.  Use blank substitution.
          if [[ -n "${LASTRECORD}" ]]; then
            RECORD="${LASTRECORD}"
          else
            RECORD="${ORIGIN}"
          fi
        else
          # There's an explicit name - qualify it
          RECORD=$( awk '{print $1}' <<<"${LINE}" )
          RECORD=$( qualifyName "${RECORD}" "${ORIGIN}" )
          LASTRECORD="${RECORD}"
        fi
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        TARGET=$( qualifyName "${TARGET}" "${ORIGIN}" )
        PRIORITY=$( awk '{print $(NF-1)}' <<<"${LINE}" )
        echo "add_mx_record $ZONE $RECORD $PRIORITY $TARGET"
        NUMRECORDS=$(( $NUMRECORDS + 1 ))
        continue
      fi

      #
      # TXT/SPF records
      if grep -qiP '^\s*([a-z\-\d\.]+\s+)?(\d+[a-z]?\s+)?IN\s+(TXT|SPF)\s+' <<<"${LINE}"; then
        # Strip trailing comments - this is trickier than normal, 'cause ';'
        #   inside quotes doesn't mean comment - only outside quotes.
        LINE=$( sed 's/^\(\([^";]*\|"[^"]*"\)*\);.*$/\1/' <<<"${LINE}" )
        if grep -qP '^\s*$' <<<"${LINE}"; then
          # If that leaves us with a blank line, just skip to the next line.
          continue
        fi
        LINE=$( sed 's/\s*$//' <<<"${LINE}" ) # Strip trailing whitespace
        # Test to see if they used "blank substitution"
        if grep -qiP '^\s+(\d+[a-z]?\s+)?IN\s+(TXT|SPF)\s+' <<<"${LINE}"; then
          # No explicit name.  Use blank substitution.
          if [[ -n "${LASTRECORD}" ]]; then
            RECORD="${LASTRECORD}"
          else
            RECORD="${ORIGIN}"
          fi
        else
          # There's an explicit name - qualify it
          RECORD=$( awk '{print $1}' <<<"${LINE}" )
          RECORD=$( qualifyName "${RECORD}" "${ORIGIN}" )
          LASTRECORD="${RECORD}"
        fi
        # Rules for TXT are annoying: http://www.zytrax.com/books/dns/ch8/txt.html
        TARGET=$( sed 's/.*\s\(TXT\|SPF\)\s\s*\(.*\)\s*$/\2/i' <<<"${LINE}" )
        if grep -qP '^\(' <<<"${TARGET}"; then 
          # If TARGET starts with a paren, it's a multi-line TXT.  Handle appropriately.
          # ie: Read next line, check for unquoted closing paren, end or repeat
          while read LINE; do
            # Strip trailing comments
            LINE=$( sed 's/^\(\([^";]*|"[^"]*"\)*\);.*$/\1/' <<<"${LINE}" )
            # Append the next line to TARGET
            TARGET="${TARGET}${LINE}"
            if grep -qP '\)\s*$' <<<"${TARGET}"; then
              # If the paren closed, we're done
              break
            fi
          done
          # Strip the outer parens, since we've got it all on one line now
          TARGET=$( sed 's/^\s*(\(.*\))\s*$/\1/' <<<"${TARGET}" )
        fi
        # This sed is a beast, but what it's doing, is to replace all '@' with the ORIGIN,
        #   but only when that '@' symbol is *not* inside quotes.
        TARGET=$( sed ':loop; s/^\(\([^"]*\)\|\("[^"]*"\)\)*@/\1${ORIGIN}./g; t loop' <<<"${TARGET}" )
        # If there are quoted strings, strip the unquoted whitespace, and
        #   condense to a single quoted string
        TARGET=$( sed 's/"\([^"]*\)"\s*/\1/g; s/\(^\|$\)/"/g' <<<"${TARGET}" )
        echo "add_txt_record ${ZONE} ${RECORD} ${TARGET}"
        NUMRECORDS=$(( ${NUMRECORDS} + 1 ))
        continue
      fi

      #
      # SRV records
      if grep -qiP '^\s*([a-z\-\d\.]+\s+)?(\d+[a-z]?\s+)?IN\s+SRV\s+\d+\s+\d+\s+\d+\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          continue # If that leaves us with a blank line, just skip to the next line.
        fi
        # Test to see if they used "blank substitution"
        if grep -qiP '^\s+(\d+[a-z]?\s+)?IN\s+SRV\s+\d+\s+\d+\s+\d+\s+' <<<"${LINE}"; then
          # No explicit name.  Use blank substitution.
          if [[ -n "${LASTRECORD}" ]]; then
            RECORD="${LASTRECORD}"
          else
            RECORD="${ORIGIN}"
          fi
        else
          # There's an explicit name - qualify it
          RECORD=$( awk '{print $1}' <<<"${LINE}" )
          RECORD=$( qualifyName "${RECORD}" "${ORIGIN}" )
          LASTRECORD="${RECORD}"
        fi
        NAME=$( cut -d\. -f3- <<<"${RECORD}" )
        SERVICE=$( cut -d. -f1 <<<"${RECORD}" )
        PROTOCOL=$( cut -d. -f2 <<<"${RECORD}" )
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        TARGET=$( qualifyName "${TARGET}" "${ORIGIN}" )
        PORT=$( awk '{print $(NF-1)}' <<<"${LINE}" )
        WEIGHT=$( awk '{print $(NF-2)}' <<<"${LINE}" )
        PRIORITY=$( awk '{print $(NF-3)}' <<<"${LINE}" )
        echo "add_srv_record ${ZONE} ${NAME} ${TARGET} ${SERVICE} ${PROTOCOL} ${PORT} ${WEIGHT} ${PRIORITY}"
        NUMRECORDS=$(( ${NUMRECORDS} + 1 ))
        continue
      fi

      #
      # PTR records
      if grep -qiP '^\s*([a-z\-\d\.]+\s+)?(\d+[a-z]?\s+)?(IN\s+)?PTR\s+' <<<"${LINE}"; then
        LINE=$( sed 's/\s*\(;.*\)\?$//' <<<"${LINE}" ) # Strip trailing whitespace/comments
        if grep -qP '^\s*$' <<<"${LINE}"; then
          continue # If that leaves us with a blank line, just skip to the next line.
        fi
        if grep -qiP '^\s+(\d+[a-z]?\s+)?(IN\s+)?PTR\s+' <<<"${LINE}"; then
          # No explicit name.  Use blank substitution.
          if [[ -n "${LASTRECORD}" ]]; then
            RECORD="${LASTRECORD}"
          else
            RECORD="${ORIGIN}"
          fi
        else
          # There's an explicit name - qualify it
          RECORD=$( awk '{print $1}' <<<"${LINE}" )
          RECORD=$( qualifyName "${RECORD}" "${ORIGIN}" )
          LASTRECORD="${RECORD}"
        fi
        # DNS Tool needs the full IP, not the ARPA FQDN.
        RECORD=$( sed 's/\.in-addr\.arpa\s*$//' <<<"${RECORD}" |
                    tr '.' '\n' | tac | tr '\n' '.' | sed 's/\.\s*$//' )
        TARGET=$( awk '{print $NF}' <<<"${LINE}" )
        TARGET=$( qualifyName "${TARGET}" "${ORIGIN}" )
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
ZONES=$( grep -liP 'in\s+soa' * )

if [ $DOZONES -eq 1 ]; then
  addzones
fi
if [ $DORECORDS -eq 1 ]; then
  addrecords
fi
