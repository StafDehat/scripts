#!/bin/bash

# Pull the full report for all relevant devices from ssportal
# http://ssportal.rackspace.com/Nimbus/Reports.aspx
# Copy/paste that crap into a file named 'blah' in an empty directory
# Run "nimbus-audit.sh ACC-ID"



awk '/^\ *######-/{n++} {print >"out"n".txt"}' blah
rm -f blah

for x in out*; do
  if [ `cat $x | wc -l` -lt 5 ]; then
    rm -f $x
  else
    mv $x `head -1 $x | cut -d- -f2`.txt
  fi
done

for x in *; do
  echo
  echo ----- ${x/.txt/} -----

  echo CPU:
  cat $x | sed -n '/^\s*cpu\s*$/,/^\s*setup\s*$/p' | grep -B 1 threshold | grep -v -- -- \
    | tr '\n' ' ' | sed 's/\s\s*/ /g' | sed 's/\(threshold = [0-9]*\)/\1\n/g' | sed 's/\s*$//'

  echo Memory:
  cat $x | sed -n '/^\s*memory\s*$/,/^\s*disk\s*$/p' | grep -B 1 threshold | grep -v -- -- \
    | tr '\n' ' ' | sed 's/\s\s*/ /g' | sed 's/\(threshold = [0-9]*\)/\1\n/g' | sed 's/\s*$//'

  echo Disk:
  (
    cat $x | sed -n '/^\s*disk\s*$/,/^\s*computer\s*$/p' | awk '/^\ *#/{n++} {print >"disk"n".txt"}'
    rm -f disk.txt
    for y in disk*; do
      DISK=`head -1 $y | sed 's/\s*//g' | sed 's_#_/_g'`
      cat $y | sed -n '/^\s*#\s*/,/^\s*fixed_default\s*$/p' | grep -B 1 threshold | grep -v -- -- \
        | tr '\n' ' ' | sed 's/\s\s*/ /g' | sed 's/\(threshold = [0-9]*\)/\1\n/g' | sed 's/\s*$//' | sort \
        | while read LINE; do
        echo "$DISK $LINE"
      done
    done
    rm -f disk*
    cat $x | sed -n '/^\s*fixed_default\s*$/,/^\s*computer\s*$/p' | grep -B 1 threshold | grep -v -- -- \
      | tr '\n' ' ' | sed 's/\s\s*/ /g' | sed 's/\(threshold = [0-9]*\)/\1\n/g' | sed 's/\s*$//' | sort \
      | while read LINE; do
      echo "Default $LINE"
    done
  ) | column -t | sed 's/^/ /'
  echo
done

