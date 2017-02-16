#!/bin/bash

B_DEVICE=/dev/xvdc
B_DIR=/data
B_FS=ext4
B_VG="vglocal$(date "+%Y%m%d")"
B_LV=lv00


#
# Function to destroy everything on a given physical device
function totalDataLoss() {
  local DEVICE="${1}"
  local CHILDREN=$( lsblk -plo NAME "${DEVICE}" | tail -n +2 | tac )

  for CHILD in ${CHILDREN}; do
    # If CHILD mounted, unmount
    if grep -qP "^\s*${CHILD}\s" /proc/mounts; then
      umount "${CHILD}"
    fi

    # If CHILD in /etc/fstab, comment
    sed -i "s|^\s*${CHILD}\s|#${CHILD}|" /etc/fstab

    # If CHILD is an LVM-LV, empty & lvremove it
    if lvs "${CHILD}" &>/dev/null; then
      dd if=/dev/zero of="${CHILD}" bs=4096 count=256
      lvremove -f "${CHILD}"
    fi
  done
  # Note - two loops, so we're certain we've nuked all the LVs
  #   before we start nuking PVs.
  for CHILD in ${CHILDREN}; do
    # If CHILD is an LVM-PV, vg[remove|reduce]
    if pvs "${CHILD}" &>/dev/null; then
      # Identify our PV's VG
      VG=$( pvs --noheadings -o vg_name "${CHILD}" | sed 's/\s*//' )
      # If we're in a VG, get out, or delete the VG if it's just our one PV
      if ! grep -qP '^\s*$' <<<"${VG}"; then
        # We're in a VG.  Is anyone else in here too?
        PVSinVG=$( pvs --noheadings -o vg_name | grep -cP "^\s*${VG}\s*$" )
        # If >1 PV in this VG, seceed
        if [[ ${PVSinVG} -gt 1 ]]; then
          vgreduce "${VG}" "${CHILD}"
        else
          vgremove "${VG}"
        fi
      fi
      # Now that we're not in a VG for sure, just delete the PV
      pvremove "${CHILD}"
    fi
  done
  # We've removed all LVM stuff, and all filesystems
  # Let's make sure there are no partition tables lying around either.
  CHILDREN=$( lsblk -plo NAME "${DEVICE}" | tail -n +2 | tac )
  for CHILD in ${CHILDREN}; do
    dd if=/dev/zero of="${DEVICE}" bs=4096 count=256
  done
}


# Check for any existing data on the thing.
BAIL=0
CHILDREN=$( lsblk -plo NAME "${B_DEVICE}" | tail -n +2 )
for CHILD in ${CHILDREN}; do
  if blkid "${CHILD}" >/dev/null; then
    echo -e 'WARNING: Device '"${CHILD}"' is not empty!'
    BAIL=1
  fi
done
if [[ ${BAIL} -ne 0 ]]; then
  echo -e 'If you continue, you will **LOSE ALL DATA** on everything listed above!'
  echo -e 'If you continue, you will **LOSE ALL DATA** on everything listed above!'
  echo -e 'If you continue, you will **LOSE ALL DATA** on everything listed above!'
  read -p "Should we continue anyway? [y/N]: " RESPONSE
  if [[ "${RESPONSE}" == "y" ]] ||
     [[ "${RESPONSE}" == "Y" ]]; then
    totalDataLoss "${B_DEVICE}"
  else
    exit 1
  fi
fi

#
# Partitions
parted -s -- ${B_DEVICE} mklabel gpt
parted -s -- ${B_DEVICE} mkpart primary 2048s -1
parted ${B_DEVICE} set 1 lvm on

#
# LVM
pvcreate ${B_DEVICE}1
vgcreate $B_VG ${B_DEVICE}1
lvcreate -W y -Z y --yes -l100%FREE -n $B_LV $B_VG

#
# Filesystem
mkfs.$B_FS /dev/mapper/${B_VG}-${B_LV}
# Reserved blocks should be 5% or 5G - whichever's smaller
SIZE=$( blockdev --getsize64 "${B_DEVICE}" )
FIVEPERCENT=$(( ${SIZE} * 5/100 ))    # 5%, in bytes
FIVEGIG=$(( 1024*1024*1024*5 ))       # 5G, in bytes
# min($FIVEPERCENT, $FIVEGIG), but in bash:
RSRVDSIZE=$(( ${FIVEPERCENT}<${FIVEGIG}?${FIVEPERCENT}:${FIVEGIG} ))
# Convert size-in-bytes to size-in-blocks:
BLKSIZE=$( blockdev --getbsz "${B_DEVICE}" )
RSRVDBLKS=$(( ${RSRVDSIZE} / ${BLKSIZE} ))
# Make the change:
tune2fs -r ${RSRVDBLKS} /dev/mapper/${B_VG}-${B_LV}

# Mounting
mkdir -p "${B_DIR}"
if [[ $( cat /sys/block/"$( basename ${B_DEVICE} )"/queue/rotational ) -eq 0 ]]; then
  mount -o discard "/dev/mapper/${B_VG}-${B_LV}" "${B_DIR}"
else
  mount "/dev/mapper/${B_VG}-${B_LV}" "${B_DIR}"
fi
sed -i "/^\s*\/dev\/mapper\/${B_VG}-${B_LV}/s/^/#/" /etc/fstab
grep "^\s*/dev/mapper/${B_VG}-${B_LV}" /proc/mounts |
  sed 's/[0-9]\+\s*$/2/' >> /etc/fstab


