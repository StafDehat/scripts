#!/bin/bash
# Author: Andrew Howard

logger "$0 ($$): Starting execution"
LOCK_FILE=/tmp/`basename $0`.lock
function cleanup {
 logger "$0 ($$): Caught exit signal - deleting trap file"
 rm -f $LOCK_FILE
 exit 2
}
logger "$0 ($$): Using lockfile ${LOCK_FILE}"
(set -C; echo "$$" > "${LOCK_FILE}") 2>/dev/null
if [ $? -ne 0 ]; then
 logger "$0 ($$): Lock File exists - exiting"
 exit 1
else
  trap 'cleanup' 1 2 15 17 19 23 EXIT
fi
 

SQLUSER=admin
SQLPASS=$( cat /etc/psa/.psa.shadow )
LOGDIR=/var/log/site-php-versions
RETENTION=14d
DATE=$( date +"%F-%T" )
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/dell/srvadmin/bin:/opt/dell/srvadmin/sbin:/root/bin"



if [[ ! -d "${LOGDIR}" ]]; then
  mkdir -p "${LOGDIR}"
fi

mysql psa -u"${SQLUSER}" -p"${SQLPASS}" -BNe "
SELECT domains.name as domain,
       sys_users.login as user,
       hosting.www_root,
       ServiceNodeEnvironment.name as phpHandler,
       RIGHT(
         LEFT(
           ServiceNodeEnvironment.value,
           LOCATE('</fullVersion>',ServiceNodeEnvironment.value) - 1
         ),
         (
           LOCATE('</fullVersion>',ServiceNodeEnvironment.value) -
           LOCATE('<fullVersion>',ServiceNodeEnvironment.value) -
           LENGTH('<fullVersion>')
         )
       ) as phpVersion
FROM hosting 
LEFT JOIN sys_users ON hosting.sys_user_id = sys_users.id
LEFT JOIN domains ON hosting.dom_id = domains.id
LEFT JOIN ServiceNodeEnvironment ON hosting.php_handler_id = ServiceNodeEnvironment.name
WHERE ServiceNodeEnvironment.section = 'phphandlers';
" | column -t > "${LOGDIR}"/"${DATE}".log

tmpwatch -m "${RETENTION}" "${LOGDIR}"

