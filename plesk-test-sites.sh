#!/bin/bash

sitePhpDir="/var/log/site-php-versions/"
latestList=$( ls -1t "${sitePhpDir}" | head -n 1 )
date=$( date +"%Y%m%d%H%M%S" )

echo "Domain PHP-Handler PHP-Version HTML-Test PHP-Test"
while read domain user webroot handler version; do
  # Skip this site if the webroot doesn't exist
  if [[ ! -d "${webroot}" ]]; then
    continue
  fi
  # Skip this site if there's VirtualHost in httpd-S
  if ! grep -qP "\s(www\.)?${domain}" /root/httpd-S; then
    continue
  fi
  echo -n "${domain} ${handler} ${version} ";
  VIRTIP=$( grep -P 'port 80 namevhost .*'"${domain}"' \(' /root/httpd-S |
              grep -oP '/etc/.*\.conf' |
              head -n 1 |
              xargs grep -Pi 'VirtualHost.*:80' |
              grep -Po '(\d+\.){3}\d+' )
  # Test HTML functionality
  echo "${domain}" > "${webroot}"/site-test.${date}.html
  curl -fsIk -m 5 http://"${VIRTIP}"/site-test.${date}.html -H "Host: www.${domain}" &>/dev/null
  RET=$?
  case "${RET}" in
    0)  echo -n "Success ";;
    28) echo -n "Timeout ";;
    *)  echo -n "Status${RET} ";;
  esac
  rm -f "${webroot}"/site-test.${date}.html
  # Test PHP functionality
  echo '<?php phpinfo(); ?>' > "${webroot}"/site-test.${date}.php
  curl -fsIk -m 5 http://"${VIRTIP}"/site-test.${date}.php -H "Host: www.${domain}" &>/dev/null
  RET=$?
  case "${RET}" in
    0)  echo -n "Success ";;
    28) echo -n "Timeout ";;
    *)  echo -n "Status${RET} ";;
  esac
  rm -f "${webroot}"/site-test.${date}.php
  # And add a newline
  echo
done < "${sitePhpDir}"/"${latestList}"

