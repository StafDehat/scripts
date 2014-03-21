#!/bin/bash

# Messiah did it
# Author: Andrew Howard


# All files will be stored relative to this directory:
CERTROOT=$HOME/ssl

# Command-line arguments
BITS=2048
while getopts ":hb:" arg
do
  case $arg in
    h  ) # Print help
         echo "Usage: $0 [-b BITS] [-h]"
         echo "Generate a CSR/key/cert with BITS bits of encryption (default $BITS)"
         echo "Example: $0 -b 2048"
         echo ""
         exit 1;;
    b  ) # Set bits of encryption
         BITS=$OPTARG
         ;;
    *  ) # Default
         echo "Usage: $0 [-b BITS] [-h]"
         echo ""
         exit 1;;
  esac
done
shift $(($OPTIND - 1))


read -p "[B]egin or [F]inish a certificate request? [B/f] " STAGE

if [ `echo "$STAGE" | grep -cE 'F|f'` -eq 0 ]; then
  ###########################
  # New certificate request #
  ###########################
  read -p "Ticket ID: " TICKET
  echo ""
  read -p "Country code (ie: US): " COUNTRY
  read -p "State/Province (ie: Iowa): " STATE
  read -p "City/Locality (ie: Cedar Falls): " CITY
  read -p "Organization (ie: Rooted Webhosting): " ORGANIZATION
  read -p "Organizational unit (ie: Tech): " ORGUNIT
  echo ""
  echo "The domain must be the exact domain that will match the URL."
  echo "If this cert will be installed to https://secure.rootmypc.net/index.php,"
  echo "  then the domain should be "secure.rootmypc.net" (no quotes)."
  read -p "Domain: " DOMAIN
  SUFFIX=`echo $DOMAIN | sed 's/.*\.\(.*\..*\)$/\1/'`
  echo ""
  echo "The email address needs to be one of the following:"
  echo "  hostmaster@$SUFFIX"
  echo "  webmaster@$SUFFIX"
  read -p "Email address: " EMAILADDR

  DATE=`date +"%F.%R"`
  TICKET=`echo $TICKET | tr a-z A-Z`
  mkdir -p $CERTROOT/$DOMAIN/$TICKET

  #
  # Write the config that will be used to generate a CSR
  echo "[ req ]" > $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  echo "prompt             = no"                     >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  echo "default_bits       = $BITS"                   >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  echo "distinguished_name = req_distinguished_name" >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  echo ""                                            >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  echo "[ req_distinguished_name ]"                  >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  [ -n "$COUNTRY" ]      && echo "C            = $COUNTRY"      >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  [ -n "$STATE" ]        && echo "ST           = $STATE"        >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  [ -n "$CITY" ]         && echo "L            = $CITY"         >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  [ -n "$ORGANIZATION" ] && echo "O            = $ORGANIZATION" >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  [ -n "$ORGUNIT" ]      && echo "OU           = $ORGUNIT"      >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  [ -n "$DOMAIN" ]       && echo "CN           = $DOMAIN"       >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf
  [ -n "$EMAILADDR" ]    && echo "emailAddress = $EMAILADDR"    >> $CERTROOT/$DOMAIN/$TICKET/$DATE.conf

  #
  # Generate a private RSA Key
  openssl genrsa -out $CERTROOT/$DOMAIN/$TICKET/$DATE.key $BITS

  #
  # Use RSA Key to generate a CSR
  openssl req -new -nodes -key    $CERTROOT/$DOMAIN/$TICKET/$DATE.key \
                          -config $CERTROOT/$DOMAIN/$TICKET/$DATE.conf \
                          -out    $CERTROOT/$DOMAIN/$TICKET/$DATE.csr

  #
  # Generate a Self-Signed Cert using the Key and CSR
  openssl x509 -req -days 365 -in      $CERTROOT/$DOMAIN/$TICKET/$DATE.csr \
                              -signkey $CERTROOT/$DOMAIN/$TICKET/$DATE.key \
                              -out     $CERTROOT/$DOMAIN/$TICKET/$DATE.ss-crt

  #
  # Create a SS-PEM file from the Key and SS-CRT
  cat $CERTROOT/$DOMAIN/$TICKET/$DATE.key \
      $CERTROOT/$DOMAIN/$TICKET/$DATE.ss-crt > $CERTROOT/$DOMAIN/$TICKET/$DATE.ss-pem

  #
  # Encrypt the SS-PEM with password 'password' to create SS-PFX
  openssl pkcs12 -export -passout pass:password -in  $CERTROOT/$DOMAIN/$TICKET/$DATE.ss-pem \
                                                   -out $CERTROOT/$DOMAIN/$TICKET/$DATE.ss-pfx

  #
  # Spit out the info needed to order the CRT
  echo
  echo "Here's all your crap:"
  echo "------------------------------------------"
  echo
  echo "CSR:             $CERTROOT/$DOMAIN/$TICKET/$DATE.csr"
  echo "KEY:             $CERTROOT/$DOMAIN/$TICKET/$DATE.key"
  echo "Self-Signed CRT: $CERTROOT/$DOMAIN/$TICKET/$DATE.ss-crt"
  echo "Self-Signed PFX: $CERTROOT/$DOMAIN/$TICKET/$DATE.ss-pfx"
  echo
  echo "Here's the CSR.  Paste it into the ticket notes:"
  cat $CERTROOT/$DOMAIN/$TICKET/$DATE.csr
else
  ####################
  # Complete request #
  ####################
  read -p "Ticket ID: " TICKET

  echo ""

  PENDING=`find $CERTROOT -type d -name $TICKET | wc -l`
  if [ $PENDING -lt 1 ]; then
    echo "There are no pending SSL orders for ticket $TICKET."
    echo "Either this script was not used to generate the CSR, or there isn't one."
    exit
  elif [ $PENDING -eq 1 ]; then
    DOMAIN=$(basename `find $CERTROOT -type d -name $TICKET | sed 's_/'$TICKET'$__'`)
  else
    # More than 1 pending request on this ticket
    # Prompt for which domain we're gonna finish
    echo "Requests exist for $PENDING different domains on this ticket:"
    X=0
    DOMAINS=`find $CERTROOT -type d -name $TICKET | sed 's_.*/\(.*\)/'$TICKET'$_\1_'`
    for DOMAIN in $DOMAINS; do
      X=$(( $X + 1 ))
      echo "$X) $DOMAIN"
    done
    read -p "Which request shall we complete? (1-$X): " OPT
    DOMAIN=`find $CERTROOT -type d -name $TICKET | \
            sed 's_.*/\(.*\)/'$TICKET'$_\1_' | \
            head -n $OPT | \
            tail -n 1`
  fi

  echo ""

  PENDING=`ls -1 $CERTROOT/$DOMAIN/$TICKET/*.conf | wc -l`
  if [ $PENDING -eq 1 ]; then
    DATE=`basename $CERTROOT/$DOMAIN/$TICKET/*.conf | cut -d\. -f1-2`
    DAY=`echo $DATE | cut -d\. -f1`
    TIME=`echo $DATE | cut -d\. -f2`
    echo "Found 1 SSL request for this ticket ID."
    echo "Using request from $DAY, $TIME."
  else
    # More than 1 pending request for this domain
    # Prompt for which date's request we're going to finish
    echo "Found $PENDING SSL reqeusts for this ticket ID:"
    X=0
    DATES=`ls -1 $CERTROOT/$DOMAIN/$TICKET/*.conf | awk -F/ '{print $NF}' | cut -d\. -f1-2 | sort -n`
    for DATE in $DATES; do
      X=$(( $X + 1 ))
      echo "$X) $DATE" | sed 's/\./ /'
    done
    read -p "Which request shall we complete? (1-$X): " OPT
    DATE=`ls -1 $CERTROOT/$DOMAIN/$TICKET/*.conf | \
          awk -F/ '{print $NF}' | \
          cut -d\. -f1-2 | \
          sort -n | \
          head -n $OPT | \
          tail -n 1`
  fi

  #
  # Prompt for CRT, save to file
  echo ""
  echo "Please paste the contents of the certificate, then press Ctrl+D"
  echo "---------------------------------------------------------------"
  cat > $CERTROOT/$DOMAIN/$TICKET/$DATE.crt
  sed -i -e 's/^\s*//' \
         -e 's/\s*$//' \
         -e '/^\s*$/d' \
         -e '/!^-/s/\s*//' $CERTROOT/$DOMAIN/$TICKET/$DATE.crt

  #
  # Create a PEM file from the Key and CRT
  cat $CERTROOT/$DOMAIN/$TICKET/$DATE.key \
      $CERTROOT/$DOMAIN/$TICKET/$DATE.crt > $CERTROOT/$DOMAIN/$TICKET/$DATE.pem

  #
  # Encrypt the PEM with password 'password' to create PFX
  openssl pkcs12 -export -passout pass:password -in  $CERTROOT/$DOMAIN/$TICKET/$DATE.pem \
                                                   -out $CERTROOT/$DOMAIN/$TICKET/$DATE.pfx

  #
  # Spit out the info certificate info
  echo ""
  echo ""
  echo "Thanks for that."
  echo "Here's all the crap you need:"
  echo "--------------------------------------------------"
  echo ""
  echo "CSR: $CERTROOT/$DOMAIN/$TICKET/$DATE.csr"
  echo "KEY: $CERTROOT/$DOMAIN/$TICKET/$DATE.key"
  echo "CRT: $CERTROOT/$DOMAIN/$TICKET/$DATE.crt"
  echo "PFX: $CERTROOT/$DOMAIN/$TICKET/$DATE.pfx"
  echo ""
  echo "Here's the KEY and CRT.  You'll need these to install it:"
  cat $CERTROOT/$DOMAIN/$TICKET/$DATE.key
  cat $CERTROOT/$DOMAIN/$TICKET/$DATE.crt

fi

