#!/bin/bash
# Author: Andrew Howard
# This script prints the absolute path to every file that's included in the
# apache config.  It assumes that the apache_root is /etc/httpd.
# Note: In debian-based systems the apache root is /etc/apache2
 
APACHEDIR=/etc/httpd
TMPDIR=/tmp/conflist
FORE=1
AFT=0
 
cd $APACHEDIR
mkdir -p $TMPDIR
rm -f $TMPDIR/authlist
touch $TMPDIR/authlist
echo "conf/httpd.conf" > $TMPDIR/newfinds
 
while [[ $FORE != $AFT ]]; do
  FORE=`cat $TMPDIR/authlist | wc -l`
 
  rm -f $TMPDIR/grepping
  mv $TMPDIR/newfinds $TMPDIR/grepping
 
  for x in `sort -u $TMPDIR/grepping`; do
    grep -Ei '^\s*include\s' "$x" |
      awk '{print $2}' |
      sed "s/['\"]//g" >> $TMPDIR/newfinds
  done
 
  cat $TMPDIR/grepping $TMPDIR/authlist $TMPDIR/newfinds | sort -u > $TMPDIR/tmp
  rm -f $TMPDIR/authlist
  mv $TMPDIR/tmp $TMPDIR/authlist
  AFT=`cat $TMPDIR/authlist | wc -l`
done
 
for x in `cat $TMPDIR/authlist`; do
  echo "$x";
done | sed '/^\//!s/^/\/etc\/httpd\//'

