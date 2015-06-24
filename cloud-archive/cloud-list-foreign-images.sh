#!/bin/bash

# Author: Andrew Howard
# Note: This script requires the BashRC framework from here:
# https://github.com/StafDehat/bashrc

# Note: Deprecated.  MyCloud portal now shows this easily.
 
AUTHTOKEN=
DDI=
REGION=

MYUSERS=$( brc-identity-listusers -a $AUTHTOKEN \
             | grep -E '^bashrc\~users\~.*?\~id' \
             | awk -F \~ '{print $NF}' )
IMAGES=$( brc-image-listimages -a $AUTHTOKEN -t $DDI -r $REGION )
IMAGEIDS=$( echo "$IMAGES" | sed -n 's/^bashrc\~images\~\(.*\?\)\~user_id\~/\1 /p' )
for USER in $MYUSERS; do
  IMAGEIDS=$( echo "$IMAGEIDS" | grep -v " $USER$" )
done
( echo "ImageID ImageName"
for IMAGEID in $( echo "$IMAGEIDS" | awk '{print $1}' ); do
  IID=$( echo "$IMAGES" | grep -E "^bashrc\~images\~$IMAGEID\~id~" | awk -F \~ '{print $NF}' )
  INAME=$( echo "$IMAGES" | grep -E "^bashrc\~images\~$IMAGEID\~name~" | awk -F \~ '{print $NF}' )
  echo "$IID $INAME"
done ) | column -t
