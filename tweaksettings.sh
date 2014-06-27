#!/bin/bash
#
#   Script to update a tweak settings value, or add it if it doesn't exist.
#
#   http://docs.cpanel.net/twiki/bin/view/AllDocumentation/InstallationGuide/AdvancedOptions#How%20to%20pre-configure%20cPanel%20%20WHM
#
#   Copyright (C) 2014 Craig Parker <craig@paragon.net.uk>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; If not, see <http://www.gnu.org/licenses/>.
#
#

# NOT MINE
# Stolen from https://github.com/ab5w/puppet-tweak_settings/blob/master/files/tweaksettings.sh
#   and modified to increase fault tolerance and improve performance.


function usage() {
  echo "Usage: $0 <variable> <value>"
}

if [ $# -ne 2 ]; then
  echo "ERROR: Incorrect number of arguments (expecting 2)"
  usage && exit 0
fi

variable=$1
value=$2

cpconfig="/var/cpanel/cpanel.config";

if ! grep -qE "^\s*$variable\s*=" $cpconfig; then
  # Variable not yet defined - add it
  echo "$variable=$value" >> $cpconfig
  `awk -F\' '/^\s*#.*whostmgr/ {print $2}' $cpconfig | head -n 1`
elif grep -qE "^\s*$variable\s*=" $cpconfig; then
  # Variable already defined - replace if different from current
  cvalue=$( awk -F= "/^\s*$variable\s*=/ {print $2}" | head -n 1 )
  if [ "$cvalue" != "$value" ]; then
    sed -i "/^\s*$variable\s*=/d" $cpconfig
    echo "$variable=$value" >> $cpconfig
    `awk -F\' '/^\s*#.*whostmgr/ {print $2}' $cpconfig | head -n 1`
  fi
fi
