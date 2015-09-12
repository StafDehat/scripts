#!/bin/bash

# Author: Andrew Howard
# Purpose: Update gateway address for specified network within route-eth0.
# Limitation: Currently unsafe if server is using routes of this format:
#   10.0.0.0/24 via 10.0.0.15
# Last updated: 2015-09-09

# To-Do:
# Take "1.2.3.0/24 via 1.2.3.4" syntax as input.
# Take ROUTEFILE (or just interface name) as command-line arg
# Make errSkipLine a helper function

#
# Hard-coded variables
ROUTEFILE="/etc/sysconfig/network-scripts/route-eth0"


#
# Verify the existence of pre-req's
PREREQS="awk cat cut echo grep id sed sort uniq"
PREREQFLAG=0
for PREREQ in $PREREQS; do
  which $PREREQ &>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Gotta have '$PREREQ' binary to run." >&2
    PREREQFLAG=1
  fi
done
if [ $PREREQFLAG -ne 0 ]; then
  exit 1
fi


#
# Usage statement
function usage() {
  cat <<EOF

Usage: setGW.sh [-d] [-h] -n NETWORK -g NEWGW

Examples:
# ./setGW.sh -h
# ./setGW.sh -d -n 10.3.4.0/26 -g 10.3.4.5
# ./setGW.sh -n 10.3.4.0/26 -g 10.3.4.5

This script sets a static route for NETWORK via the gateway NEWGW.
If a route already exists for the given NETWORK, the gateway will be changed.
If a route does not already exist, it will be added.

Arguments:
  -d    Optional.  Dry-run.  Don't change files - just print to STDOUT
        the data we *would* output into route-eth0.
  -g X  Set new gateway address to X.
  -h    Optional.  Print this help.
  -n X  Set the gateway for network range X (CIDR).
  
EOF
}


#
# Helper function - test if argument is a valid IPv4 address
function validIPv4() {
  grep -qP '^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$' <<<"$1"
  if [ $? -eq 0 ]; then
    return 0
  fi
  return 1
}


#
# Helper function - convert a CIDR to subnet mask
# This isn't the most efficient implementation, but I wanted to write
#   my own rather than steal something from the internet.
function cidr2nm() {
  local NETMASK=""
  local CIDR="$1"
  for QUAD in {1..4}; do
    if [ $CIDR -ge 8 ]; then
      NETMASK="${NETMASK}.255"
    elif [ $CIDR -ge 1 ]; then
      NETMASK="${NETMASK}.$(( 256 - 2**(8-$CIDR) ))"
    else
      NETMASK="${NETMASK}.0"
    fi
    CIDR=$(( $CIDR - 8 ))
  done
  NETMASK="$( cut -d\. -f2- <<<"$NETMASK" )" # Trim the leading '.'
  echo "$NETMASK"
}


#
# Handle command-line arguments
NEWGW=""
NETWORK=""
DRYRUN=0
USAGEFLAG=0
while getopts ":dg:hn:" arg; do
  case $arg in
    d) DRYRUN=1;;
    g) NEWGW="$OPTARG";;
    h) usage && exit 0;;
    n) NETWORK="$OPTARG";;
    :) echo "Error: Option -$OPTARG requires an argument." >&2
       USAGEFLAG=1;;
    *) echo "Error: Invalid option: -$OPTARG" >&2
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))


#
# Verify command-line arg NEWGW
if [ -z "$NEWGW" ]; then
  echo "Error: Must define NEWGW as argument." >&2
  USAGEFLAG=1
# Test that NEWGW is a valid IPv4 address
elif ! validIPv4 "$NEWGW"; then
  echo "Error: Specified gateway ($NEWGW) is not a valid IPv4 address." >&2
  USAGEFLAG=1
fi


#
# Verify command-line arg NETWORK
# BEGIN null test
if [ -z "$NETWORK" ]; then
  echo "Error: Must define NETWORK as argument." >&2
  USAGEFLAG=1
else
  # Check whether this is valid CIDR format (ie: foo/bar)
  # BEGIN notation test
  if ! grep -q / <<<"$NETWORK"; then
    echo "Error: NETWORK ($NETWORK) is not a valid CIDR network." >&2
    USAGEFLAG=1
  else
    # Split NETWORK into its network address, and its CIDR mask
    NETADDR="$( cut -d/ -f1 <<<"$NETWORK" )"
    CIDR="$( cut -d/ -f2- <<<"$NETWORK" )"

    # Test that NETADDR is a valid IPv4 address
    # BEGIN netaddr test
    if ! validIPv4 "$NETADDR"; then
      echo "Error: Address portion of NETWORK ($NETADDR) is not a valid IPv4 address." >&2
      USAGEFLAG=1
    fi # END netaddr test

    # Test that CIDR is numeric, and in the range {0..32}
    # BEGIN cidr test
    if ! grep -qP '^\d+$' <<<"$CIDR"; then
      echo "Error: Invalid CIDR mask ($CIDR) - must be numeric." >&2
      USAGEFLAG=1
    elif [ $CIDR -gt 32 ]; then
      echo "Error: Invalid CIDR mask ($CIDR) - must be between 0 and 32." >&2
      USAGEFLAG=1
    fi # END cidr test

  fi # END notation test
fi # END null test


#
# Exit if USAGEFLAG got set by any invalid args
if [ $USAGEFLAG -ne 0 ]; then
  usage && exit 3
fi


# Okay, so now we've got both valid syntax and arguments.
# Let's get down to business.


#
# Confirm we're root
if [ $(id -u) -ne 0 ]; then
  echo "Error: Script must be executed as root (UID:0)." >&2
  exit 4
fi


#
# Read current content of route-eth0 into parallel arrays
# Each route will be stored as "ADDRESS[x]/NETMASK[x] via GATEWAY[x]"
declare -a ADDRESS
declare -a NETMASK
declare -a GATEWAY
INDEX=0
IPROUTES=""
# This file could contain entries in one of two formats.  I'm honestly not
#   certain if mixing those two formats is legal, so I'll just assume it is
#   for my input.
# "x/y via z" lines are non-positional, so we'll just append those to the end.
# That means we need to parse all the "var=val" lines first, since those are
#   positional (ie: ADDRESS0, ADDRESS1, etc).
if [ -f "$ROUTEFILE" ]; then
  while read LINE; do
    SYNTAXFLAG=0
    if grep -qP '^\s*(#.*)?$' <<<"$LINE"; then
      continue # Blank line or all-comment line - skip it
    fi
    if grep -qP '^\s*ADDRESS' <<<"$LINE"; then
      # Seems to be "ADDRESSx=y.y.y.y" format - confirm
      INDEX="$( sed 's/^\s*ADDRESS\([0-9]*\)\s*=.*/\1/' <<<"$LINE" )"
      VALUE="$( cut -d= -f2- <<<"$LINE" | sed 's/\s*(#.*)?$//' )"
      validIPv4 "$VALUE" && 
        ADDRESS[$INDEX]="$VALUE" || 
        echo -e "Warning: Unexpected content - skipping this line:\n  $LINE" >&2
    elif grep -qP '^\s*NETMASK' <<<"$LINE"; then
      # Seems to be "NETMASKx=y.y.y.y" format - confirm
      INDEX="$( sed 's/^\s*NETMASK\([0-9]*\)\s*=.*/\1/' <<<"$LINE" )"
      VALUE="$( cut -d= -f2- <<<"$LINE" | sed 's/\s*(#.*)?$//' )"
      validIPv4 "$VALUE" && 
        NETMASK[$INDEX]="$VALUE" ||
        echo -e "Warning: Unexpected content - skipping this line:\n  $LINE" >&2
    elif grep -qP '^\s*GATEWAY' <<<"$LINE"; then
      # Seems to be "GATEWAYx=y.y.y.y" format - confirm
      INDEX="$( sed 's/^\s*GATEWAY\([0-9]*\)\s*=.*/\1/' <<<"$LINE" )"
      VALUE="$( cut -d= -f2- <<<"$LINE" | sed 's/\s*(#.*)?$//' )"
      validIPv4 "$VALUE" && 
        GATEWAY[$INDEX]="$VALUE" ||
        echo -e "Warning: Unexpected content - skipping this line:\n  $LINE" >&2
    elif grep -qP '^\s*\d+' <<<"$LINE"; then
      # Must be "x/y via z" format - confirm, then save for later
      grep -qP '' <<<"$LINE"
      ### Validate syntax of this line
      ### If invalid, print error
      ### Else:
      IPROUTES="$IPROUTES\n$LINE"
    else
      # This line *must* be a syntax error.  That means we can't possibly hurt
      #   anything by ignoring it and regenerating the file with known-good
      #   syntax.  Print a warning and move on.
      echo -e "Warning: Unexpected content - skipping this line:\n  $LINE" >&2
    fi
  done <"$ROUTEFILE"
fi


#
# Do a quick check that all three arrays have the exact same indices filled
# First we count how many times each index occurred:
INDEXCOUNT="$( echo "${!ADDRESS[@]} ${!NETMASK[@]} ${!GATEWAY[@]}" |
               sed 's/\s\s*/\n/g' | #Sub whitespace with newlines
               sort -n | 
               uniq -c | 
               sort -n )"
# Strip down to only indices that occurred exactly 3 times (once in each array)
INDICES="$( awk '$1 ~ /^3$/ {print $2}' <<<"$INDEXCOUNT" )"
# Print a warning if there were any entries *not* in all three arrays
if [ $(wc -l <<<"$INDEXCOUNT") -ne $(wc -l <<<"$INDICES") ]; then
  echo "Warning: Some routes were partially defined, and were omitted." >&2
fi


#
# Now that we definitely know the last index of the valid "var=val" routes,
#   we can now append the non-positional "x/y via z" routes to the end.
echo "CIDR-based Routes:"
echo "$IPROUTES"


#
# Find which array index contains our specified network address and netmask
# Reminder on command-line args, since we're finally using them:
#  -n $NETADDR/$CIDR
#  -g $NEWGW
CIDR2NM=$( cidr2nm "$CIDR" )
INDEXFLAG=0
for INDEX in $INDICES; do
  if [ "${ADDRESS[$INDEX]}" == "$NETADDR" ]; then
    if [ "${NETMASK[$INDEX]}" == "$CIDR2NM" ]; then
      INDEXFLAG=1
      break #INDEX will maintain the value we care about
    fi
  fi
done


#
# Add or adjust the specified route in our parallel arrays
if [ $INDEXFLAG -eq 1 ]; then
  # If INDEXFLAG is set, we found an existing definition for the specified
  #   route - we'll need to edit the GATEWAY at that INDEX.
  GATEWAY[$INDEX]="$NEWGW"
else
  # If INDEXFLAG is unset, then we didn't find the specified network in any
  #   existing route definitions.  That means we're adding, not editing.
  if [ -z "$INDICES" ]; then
    # If *no* valid routes already existed, that's a special case.
    # Insert new route at index 0.
    INDEX=0
  else
    # Otherwise, we'll need to find the highest-indexed route, add one
    #   to that index, and insert the new route at that next index.
    # Note: The sorting isn't strictly necessary - it will already be sorted
    #   due to how we defined INDICES.  This just future-proofs it.
    INDEX=$( echo "$INDICES" | 
               sed 's/\s\s*/\n/g' | # Sub whitespace with newlines
               sort -n | tail -n 1 )
    INDEX=$(( $INDEX + 1 ))
  fi
  # Insert the new element
  ADDRESS[$INDEX]="$NETADDR"
  NETMASK[$INDEX]="$CIDR2NM"
  GATEWAY[$INDEX]="$NEWGW"
  # By adding that entry, we've now added a new valid-index, so update
  #   INDICES with that new INDEX.
  INDICES="$INDICES $INDEX"
fi
# Parallel arrays should now contain all desired network information.


#
# Write out the array data to route-eth0 format
OUTPUT=$( 
  for INDEX in $INDICES; do
    echo "ADDRESS${INDEX}=${ADDRESS[$INDEX]}"
    echo "NETMASK${INDEX}=${NETMASK[$INDEX]}"
    echo "GATEWAY${INDEX}=${GATEWAY[$INDEX]}"
  done )


#
# Clobber route-eth0 with the data from our parallel arrays
#   unless "-d" was passed, then just echo the data instead.
if [ $DRYRUN -eq 0 ]; then
  echo "$OUTPUT" >"$ROUTEFILE"
else
  echo "$OUTPUT"
fi


exit 0

