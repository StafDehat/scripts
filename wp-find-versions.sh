#!/bin/bash

# Author: Andrew Howard
# Desc: Find wordpress installs on this system and print the version

if [ `id -u` -ne 0 ]; then
  echo "Must run as root"
  exit 1
fi

updatedb

locate wp-includes/version.php | \
while read x; do 
  echo -n "$x : "
  egrep '^\s*\$wp_version\s*=' "$x" | cut -d\' -f2
done | column -t -s : > wp-versions
