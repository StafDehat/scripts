#!/bin/bash

# Author: Andrew Howard

function min() {
  if [ $1 -lt $2 ]; then
    echo $1
  else
    echo $2
  fi
}

SRUUID=$( xe sr-list name-label="Local storage" params=uuid --minimal )
SRSIZE=$( xe sr-list uuid=$SRUUID params=physical-size --minimal )
SRUSED=$( xe sr-list uuid=$SRUUID params=physical-utilisation --minimal )

# Grab the complete list of snapshots on this Hyp
SNAPSHOTS=$( xe vdi-list is-a-snapshot=true params=uuid sr-uuid=$SRUUID --minimal | tr ',' ' ' )

# Strip the list down to only *old* snapshots
HOURS=24
EXPIRE=$(( 60 * 60 * $HOURS ))
EXPIRE=$(( 60 * 60 * $HOURS ))
OLDSNAPS=""
for SNAPSHOT in $SNAPSHOTS; do
  DATE=$( xe vdi-list uuid=$SNAPSHOT params=snapshot-time --minimal )
  DATE=$( date +%s -d "$( echo $DATE | sed 's/T/ /' )" )
  NOW=$( date +%s )
  AGE=$(( $NOW - $DATE ))
  if [ $AGE -gt $EXPIRE ]; then
    OLDSNAPS="$OLDSNAPS $SNAPSHOT"
  fi
done

# Calculate potential-max of disk space increase as a result of coalesce processes
DELETIONS=""
MaxDiskIncrease=0
for SNAPSHOT in $OLDSNAPS; do
  DATE=$( xe vdi-list uuid=$SNAPSHOT params=snapshot-time --minimal )
  DATE=$( date +"%F %T" -d "$( echo $DATE | sed 's/T/ /' )" )
  echo "Checking snapshot VHD $SNAPSHOT (Created $DATE)"
  SKIP=1
  # There's a parent field, but it might not be used - data's probably actually in sm-config
  # Attempt to check both
  PARENT1=$( xe vdi-list uuid=$SNAPSHOT params=sm-config --minimal | 
              sed 's/\s\s*/\n/g' | grep -A 1 "vhd-parent:" | tail -n 1 )
  PARENT2=$( xe vdi-list params=parent uuid=$SNAPSHOT | cut -d: -f2- )
  if [[ ( -z "$PARENT1" || $( grep -c "not in database" <<<"$PARENT1" ) -ne 0 ) &&
        ( -z "$PARENT2" || $( grep -c "not in database" <<<"$PARENT2" ) -ne 0 ) ]]; then
    # Both empty
    SKIP=1
  elif [[ -z "$PARENT1" || $( grep -c "not in database" <<<"$PARENT1" ) -ne 0 ]]; then
    # Only sm-config empty, but parent field set
    PARENT=$PARENT2
    SKIP=0
  elif [[ -z "$PARENT2" || $( grep -c "not in database" <<<"$PARENT2" ) -ne 0 ]]; then
    # Only parent empty, but sm-config field set
    PARENT=$PARENT1
    SKIP=0
  elif [ "$PARENT1" == "$PARENT2" ]; then
    # Both are set, and they're identical
    PARENT=$PARENT1
    SKIP=0
  else
    # Both are set, but to different values
    SKIP=1
  fi
  # Confirm there *is* a parent - if not, don't delete this snapshot
  if [ $SKIP -ne 0 ]; then
    echo "Unable to identify parent VHD of $SNAPSHOT - skipping this one"
  else
    DiffDisk=$( xe vdi-list is-a-snapshot=false sm-config:vhd-parent=$PARENT params=uuid --minimal )
    if [ -z "$DiffDisk" ]; then
      echo "WARNING: Snapshot $SNAPSHOT has no non-snapshot siblings."
    else
      DELETIONS="$DELETIONS $SNAPSHOT"
      DiffSize=$( du -b /var/run/sr-mount/$SRUUID/$DiffDisk.vhd | awk '{print $1}' )
      ParentVirtualSize=$( xe vdi-list params=virtual-size uuid=$PARENT --minimal )
      ParentRealSize=$( du -b /var/run/sr-mount/$SRUUID/$PARENT.vhd | awk '{print $1}' )
      MaxDiskIncrease=$(( $MaxDiskIncrease +
                          $( min $DiffSize \
                                 $(( $ParentVirtualSize - $ParentRealSize )) ) ))
    fi
  fi
done

# If max disk growth from coalesce keeps the SR <95%, go ahead and delete
# Otherwise, quit with warning.
SAFEZONE=$( echo "$SRSIZE * 0.95" | bc -l | cut -d\. -f1 )
if [ $(( $SRUSED + $MaxDiskIncrease )) -lt $SAFEZONE ]; then
  # Guaranteed safe to delete snapshots.  Even worst-case disk growth won't fill the SR.
  # Delete snapshot VDIs
  echo
  echo "SR Size:    $SRSIZE"
  echo "SR Used:    $SRUSED"
  echo "Max change: $MaxDiskIncrease"
  echo
  echo "Recommend the following deletions:"
  for SNAPSHOT in $DELETIONS; do
    echo "xe vdi-destroy uuid=$SNAPSHOT"
  done
else
  # It's possible deleting snapshots could fill the SR
  # It might be possible to delete snapshots in a particular order to avoid filling the SR
  # Just get manual intervention here
  echo 'WARNING: A coalesce *might* fill this SR'
  echo 'Recommend manual intervention at this point'
fi

