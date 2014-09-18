#!/bin/bash

if [ $# -ne 1 ]; then
  echo "ERROR: Must provide a single Cloud Server ID (Nova's UUID) as argument."
  exit 1
elif grep -qvE '^[0123456789abcdef-]*$' <<<"$1"; then
  echo "ERROR: Invalid characters in UUID."
  echo "Valid characters are: 1234567890abcdef-"
  exit 2
fi


#
# Echo self, then recurse on each of your children
function depth-first() {
  VDIUUID=$1
  echo $VDIUUID
  NEWCHILDREN=$( xe vdi-list sm-config:vhd-parent=$VDIUUID --minimal | tr ',' '\n' )
  for CHILD in $NEWCHILDREN; do
    depth-first $CHILD
  done
}


#
# Get a list of all VDIs connected directly to this VM
NOVAID=$1
VMUUID=$( xe vm-list name-label=instance-$NOVAID --minimal )
VDILIST=$( xe vbd-list vm-uuid=$VMUUID params=vdi-uuid --minimal | tr ',' '\n' )


#
# Find all the top-level parents of the VDIs
PARENTLIST=""
for VDIUUID in $VDILIST; do 
  while true; do
    PARENT=$VDIUUID
    VDIUUID=$( xe vdi-param-get param-name=sm-config param-key=vhd-parent uuid=$VDIUUID 2>/dev/null )
    if [ -z "$VDIUUID" ]; then
      break
    fi
  done
  PARENTLIST="$PARENTLIST $PARENT"
done


#
# Walk down the tree for each VDI in the parent list
VDILIST=""
for PARENT in $PARENTLIST; do
  VDILIST="$VDILIST $( depth-first $PARENT )"
done


#
# Run a VHD scan on only the relevant VHDs
VHDOUTPUT=$( vhd-util scan -f -p -m \
  $( for VDI in $VDILIST; do echo -n "/var/run/sr-mount/*/$VDI.vhd "; done ) )


#
# Add names, snapshot flags, and fancy output
( 
echo "VM-Name:Plugged-Into:As-Device:Size:Snapshot?:VDI-UUID"
IFS=''
while read LINE; do
  SPACING=$( sed 's/^\(\s*\).*$/\1/' <<<"$LINE" )
  VDIUUID=$( sed 's/.*vhd=\([0123456789abcdef-]*\)\.vhd.*$/\1/' <<<"$LINE" )
  VHDSIZE=$( sed 's/.*size=\([0123456789]*\) .*$/\1/' <<<"$LINE" |
               awk '{ sum=$1;
                      hum[1024**3]="Gb";
                      hum[1024**2]="Mb";
                      hum[1024]="Kb";
                      for (x=1024**3; x>=1024; x/=1024) {
                        if (sum>=x) { printf "%.2f %s\n",sum/x,hum[x];break } }}' )
  SNAPSHOT=$( xe vdi-param-get param-name=is-a-snapshot uuid=$VDIUUID )
  DEVICE=$( xe vbd-list params=device vdi-uuid=$VDIUUID --minimal )
  if [ -z "$DEVICE" ]; then DEVICE="---"; fi
  PLUGGED=$( xe vbd-list params=vm-name-label vdi-uuid=$VDIUUID --minimal )
  if [ -z "$PLUGGED" ]; then PLUGGED="---"; fi
  VMNAME=$( xe vdi-param-get param-name=name-label uuid=$VDIUUID )
  echo "$SPACING$VMNAME:$PLUGGED:$DEVICE:$VHDSIZE:$SNAPSHOT:$VDIUUID"
done <<<"$VHDOUTPUT"
) | column -s : -t

