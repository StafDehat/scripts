#!/bin/bash

function min() {
  if [ $1 -lt $2 ]; then
    echo $1
  else
    echo $2
  fi
}

SRUUID=$( xe sr-list name-label="Local storage" params=uuid | awk '/^uuid/ {print $NF}' )
SRSIZE=$( xe sr-list uuid=$SRUUID params=physical-size | awk '/^physical-size/ {print $NF}' )
SRUSED=$( xe sr-list uuid=$SRUUID params=physical-utilisation | awk '/^physical-utilisation/ {print $NF}' )

# Grab the complete list of snapshots on this Hyp
SNAPSHOTS=$( xe vdi-list is-a-snapshot=true params=uuid sr-uuid=$SRUUID | awk '/^uuid/ {print $NF}' )

# Strip the list down to only *old* snapshots
HOURS=24
EXPIRE=$(( 60 * 60 * $HOURS ))
EXPIRE=$(( 60 * 60 * $HOURS ))
OLDSNAPS=""
for SNAPSHOT in $SNAPSHOTS; do
  DATE=$( xe vdi-list uuid=$SNAPSHOT params=snapshot-time | awk '{print $NF}' )
  DATE=$( date +%s -d "$( echo $DATE | sed 's/T/ /' )" )
  NOW=$( date +%s )
  AGE=$(( $NOW - $DATE ))
  if [ $AGE -gt $EXPIRE ]; then
    OLDSNAPS="$OLDSNAPS $SNAPSHOT"
  fi
done

# Calculate potential-max of disk space increase as a result of coalesce processes
MaxDiskIncrease=0
for SNAPSHOT in $OLDSNAPS; do
  PARENT=$( xe vdi-list params=parent uuid=$SNAPSHOT | cut -d: -f2- )
  # Confirm there *is* a parent - if not, don't delete this snapshot
  if [[ -z "$PARENT" ||
        $( grep -c "not in database" <<<$PARENT ) -ne 0 ]]; then
    echo "Unable to identify parent VHD of $SNAPSHOT - skipping this one"
  else
    DELETIONS="$DELETIONS $SNAPSHOT"
    DiffDisk=$( xe vdi-list is-a-snapshot=false parent=$PARENT params=uuid | awk '/^uuid/ {print $NF}' )
    DiffSize=$( du -b /var/run/sr-mount/$SRUUID/$DiffDisk.vhd | awk '{print $1}' )
    ParentVirtualSize=$( xe vdi-list params=virtual-size uuid=$PARENT | awk '/^virtual-size/ {print $NF}' )
    ParentRealSize=$( du -b /var/run/sr-mount/$SRUUID/$PARENT.vhd | awk '{print $1}' )
    MaxDiskIncrease=$(( $MaxDiskIncrease +
                        $( min $DiffSize \
                               $(( $ParentVirtualSize - $parentRealSize )) ) ))
  fi
done

# If max disk growth from coalesce keeps the SR <95%, go ahead and delete
# Otherwise, quit with warning.
SAFEZONE=$( echo "$SRSIZE * 0.95" | bc -l | cut -d\. -f1 )
if [ $(( $SRUSED + $MaxDiskIncrease )) -lt $SAFEZONE ]; then
  # Guaranteed safe to delete snapshots.  Even worst-case disk growth won't fill the SR.
  # Delete snapshot VDIs
  echo "SR Size:    $SRSIZE"
  echo "SR Used:    $SRUSED"
  echo "Max change: $MaxDiskIncrease"
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

