#!/bin/bash

echo "Please copy/paste the error message from backstage/ohthree"
echo "Example: HOST_NOT_ENOUGH_FREE_MEMORY: 8662286336; 8434565120"
echo
read -p ">> " ERROR

echo
echo "Now I need the UUID of the slice.  Not the name-label.  The UUID."
read -p ">> " UUID

NEEDED=`echo $ERROR | perl -pe 's/^.*?(\d+).*$/\1/'`
AVAILABLE=`echo $ERROR | perl -pe 's/^.*?(\d+).*?(\d+).*$/\2/'`

NEWMEM=`echo $(( $NEEDED / 256000000 * 250000000 ))`

echo "Run these on the hypervisor:"
echo "# xe vm-memory-limits-set uuid=$UUID static-min=$NEWMEM static-max=$NEWMEM dynamic-min=$NEWMEM dynamic-max=$NEWMEM"
echo "# xe vm-param-clear param-name=blocked-operations uuid=$UUID"
echo "# xe vm-start uuid=$UUID"



