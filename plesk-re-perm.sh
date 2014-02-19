#!/bin/bash

cd /home/httpd/vhosts
for x in *; do
  grep $x /etc/passwd
done | awk -F : '{print $1" "$6}' > /tmp/userdirs

cat /tmp/userdirs | while read x; do
  NAME=`echo $x | cut -d\  -f1`
  DIR=`echo $x | cut -d\  -f2`
  cd $DIR
  chown -R $NAME httpdocs httpsdocs private anon_ftp error_docs cgi-bin

  chgrp -R psacln httpdocs httpsdocs cgi-bin/*

  chown -R root conf statistics

  chgrp -R psaserv statistics anon_ftp error_docs
  chgrp psaserv bin conf pd httpdocs httpsdocs subdomains web_users

  chgrp root anon_ftp/incoming/quotadir statistics/anon_ftpstat statistics/ftpstat statistics/webstat*
  chown root bin pd error_docs subdomains web_users anon_ftp/conf subdomains/*
done

exit


# Need to add subdomain fixes too
  cd subdomains
  for y in *; do
    cd $DIR/subdomains/$y
    chown -R $NAME httpdocs httpsdocs error_docs cgi-bin

    chgrp -R psacln httpdocs httpsdocs cgi-bin/*

    chown -R root conf

    chgrp -R psaserv error_docs
    chgrp psaserv conf httpdocs httpsdocs

    chown root error_docs
  done

