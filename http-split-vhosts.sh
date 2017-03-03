#!/bin/bash

# Author: Andrew Howard

# Force newlines around virtualhost tags
sed 's/^[^#]*\(<\s*\/\?\s*virtualhost[^>]*>\)/\n\1\n/gI' blah > newblah

# New file at every virtualhost tag
awk 'IGNORECASE=1;/^\s*<\s*\/?\s*virtualhost/{n++} {print >"tmp/out"n".txt"}' newblah

# Delete the out*.txt files that don't contain a VirtualHost
cd tmp
comm -13 <( grep -lPi '^\s*<\s*virtualhost' * | sort ) <( for x in *; do echo "${x}"; done | sort ) | xargs rm -f

# Add closing VirtualHost tags to what's left
for x in *; do echo "</VirtualHost>" >> $x; done

# Rename files to vhost names
for x in *; do
  servername=$( grep -ioP '^\s*servername\s+[^\s]+' $x | awk '{print $2}' | tr 'A-Z' 'a-z' )
  cat "$x" >> "$servername.conf"
  rm -f "$x"
done

# Pull all global config from original file, into newblah
cd ..
sed -i '/<\s*virtualhost/I,/<\s*\/\s*virtualhost/Id' newblah

# Move newblah to httpd.conf now, 'cause it's all the global stuff
# And rename 'tmp' to "vhost.d"

