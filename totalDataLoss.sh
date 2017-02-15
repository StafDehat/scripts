#!/bin/bash

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
