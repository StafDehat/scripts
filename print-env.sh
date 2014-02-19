#!/bin/bash

# Work in progres.
# Goal is to run this on a source server in a migration to help avoid missing things


# MySQL
mysql -V
sed 's/#.*$//' /etc/my.cnf | grep -vE '^\s*$' | sed '/\[.*\]/s/^/\n/'


# Apache
( /usr/local/apache/bin/httpd -v || /usr/sbin/httpd -v ) 2>/dev/null


# PHP
php -v

