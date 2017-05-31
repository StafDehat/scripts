#!/bin/bash

#Check if specified device exists
#Check for existing mount point & vgname prior to deleting data





#
# Verify the existence of pre-req's
PREREQS="parted partprobe"
PREREQFLAG=0
for PREREQ in $PREREQS; do
  which $PREREQ &>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Gotta have '$PREREQ' binary to run."
    PREREQFLAG=1
  fi
done
if [ $PREREQFLAG -ne 0 ]; then
  exit 1
fi

#
# Define a usage statement
function usage() {
  echo "Usage: $0 [-h]\\"
  echo "          -b BlockDevice \\"
  echo "          -d Directory \\"
  echo "          [-f Filesystem] \\"
  echo "          -l LVName \\"
  echo "          -v VGName"
  echo
  echo "Example: $0 -b /dev/sdb -d /data -v vg00 -l lv00 -f ext4"
  echo
  echo "Arguments:"
  echo "  -b X  Block device to partition/pvcreate/format."
  echo "        WARNING: All data on this device will be lost."
  echo "  -d X  Mountpoint for newly-created LVM logical volume."
  echo "  -f X  Filesystem to use for mkfs on the newly-created LVM logical volume."
  echo "  -h    Print this help."
  echo "  -l X  LVM Logical volume name."
  echo "  -v X  LVM Volume group name."
}

#
# Handle command-line args
B_DEVICE=""
B_DIR=""
B_FS=ext4
B_VG=""
B_LV=""
USAGEFLAG=0
while getopts ":b:d:f:hl:v:" arg; do
  case $arg in
    b) B_DEVICE="${OPTARG}";;
    d) B_DIR="${OPTARG}";;
    f) B_FS="${OPTARG}";;
    h) usage && exit 0;;
    l) B_LV="${OPTARG}";;
    v) B_VG="${OPTARG}";;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))
# Verify required arguments were passed
ReqArgs="B_DEVICE B_DIR B_VG B_LV"
for ARGUMENT in ${ReqArgs}; do
  if [ -z "${!ARGUMENT}" ]; then
    echo "ERROR: Must define $ARGUMENT as argument."
    USAGEFLAG=1
  fi
done
# Bail, maybe
if [ "$USAGEFLAG" -ne 0 ]; then
  usage && exit 1
fi



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
  partprobe
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
# Test for conflicting VG
VGS=$( vgs --noheadings -o vgname )
if grep -qP "^\s*${B_VG}\s*$" <<<"${VGS}"; then
  echo
  echo "ERROR: You're attempting to create a new LVM Volume Group named '${B_VG}',"
  echo "  but that already exists:"
  vgs
  exit 2
fi

#
# Test for conflicting mountpoint
if mountpoint "${B_DIR}" &>/dev/null; then
  echo
  echo "ERROR: You're attempting to mount the new LV at '${B_DIR}'"
  echo "  but something is already mounted there:"
  df -h "${B_DIR}"
  exit 3
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

