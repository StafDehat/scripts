#!/bin/bash

#Author: Andrew Howard

VMNAME=$1
(
echo "UserDevice Type Size UUID"
if [ $( echo "$VMNAME" | grep -cE '^instance-' ) -eq 0 ]; then
  VMNAME="instance-$VMNAME"
fi
VMUUID=$( xe vm-list name-label=$VMNAME params=uuid )
VBDS=$( xe vbd-list vm-name-label=$VMNAME params=uuid | awk '{print $NF}' )
for VBD in $VBDS; do
  USERID=$( xe vbd-list uuid=$VBD params=userdevice | awk '{print $NF}' )
  VDI=$( xe vbd-list uuid=$VBD params=vdi-uuid | awk '{print $NF}' )
  VDISIZE=$( xe vdi-list uuid=$VDI params=virtual-size | awk '{print $NF}' )
  VDISIZE=$(( $VDISIZE / 1024 / 1024 / 1024 ))
  SRUUID=$( xe vdi-list uuid=$VDI params=sr-uuid | awk '{print $NF}' )
  if [ $( echo "$SRUUID" | grep -cE '^FA15E-D15C-' ) -gt 0 ]; then
    # This is block storage
    echo "$USERID CBS ${VDISIZE}G ${SRUUID/FA15E-D15C-/}"
  else
    # This is not block storage
    echo "$USERID LocalDisk ${VDISIZE}G"
  fi
done | sort -n
) | column -t
