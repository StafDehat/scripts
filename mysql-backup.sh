#!/bin/bash

# Author: Andrew Howard

logger "$0 ($$): Starting execution"
LOCK_FILE=/tmp/"$( basename $0 ).lock"
function cleanup {
 logger "$0 ($$): Caught exit signal - deleting trap file"
 [[ -f "${CNF}" ]] && rm -f "${CNF}"
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


#
# User configurables
SQLUSER="xxxxxxxx"
SQLPASS="xxxxxxxx"
BACKUPDIR="/home/rack/mysqldump"
RETENTION=3

#
# Less common user configurables
declare -a DUMPOPTS
DUMPOPTS+=("--events")
DUMPOPTS+=("--routines")
DUMPOPTS+=("--triggers")
DUMPOPTS+=("--disable-keys")
DUMPOPTS+=("--extended-insert")
DUMPOPTS+=("--add-locks")
#DUMPOPTS+=("--insert-ignore")
DUMPOPTS+=("--quick")
DUMPOPTS+=("--quote-names")
if [[ "$( ${MYSQL} -bNe "SHOW VARIABLES LIKE 'log_bin';" )" == "ON" ]]; then
  DUMPOPTS+=("--master-data=2")
fi
MYSQLDUMP="/usr/bin/mysqldump --defaults-extra-file=${CNF} ${DUMPOPTS[@]}"
MYSQL="/usr/bin/mysql --defaults-extra-file=${CNF}"

#
# Untouchables
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
DATE="$( date +%Y-%m-%d )"
CNF="$( mktemp )"
cat <<EOF >"${CNF}"
[client]
user="${SQLUSER}"
password="${SQLPASS}"
EOF


#
# Verify backup directory exists
umask 0066
if [[ ! -d "${BACKUPDIR}"/"${DATE}" ]]; then
  mkdir -p "${BACKUPDIR}"/"${DATE}"
  chmod 0700 "${BACKUPDIR}"/"${DATE}"
fi

#
#  Get list of MySQL databases
echo "Generating list of all databases"
DBS="$( ${MYSQL} --skip-column-names -e "show databases;" )"

#
# Back 'em up
for DB in ${DBS}; do
  if [[ "${DB}" == "information_schema" ]]; then
    echo "Skipping database '${DB}'"
    continue
  fi
  echo "Creating backup directory for DB '${DB}'"
  mkdir -p "${BACKUPDIR}"/"${DATE}"/"${DB}"
  echo "Generating list of tables in '${DB}'"
  TABLES="$( ${MYSQL} "${DB}" -bNe "show tables;" )"
  for TABLE in ${TABLES}; do
    echo "Backing up '${DB}.${TABLE}'"
    ENGINE="$( ${MYSQL} -bNe "SELECT ENGINE FROM information_schema.TABLES
                               WHERE TABLE_SCHEMA = '${DB}'
                                 AND TABLE_NAME = '${TABLE}';" )"
    if [[ "${ENGINE}" == "InnoDB" ]]; then
      ${MYSQLDUMP} "${DB}" "${TABLE}"
    else
      ${MYSQLDUMP} --single-transaction "${DB}" "${TABLE}"
    fi > "${BACKUPDIR}"/"${DATE}"/"${DB}"/"${TABLE}.sql"
    echo "Compressing ${BACKUPDIR}/${DATE}/${DB}/${TABLE}.sql"
    gzip "${BACKUPDIR}"/"${DATE}"/"${DB}"/"${TABLE}.sql"
  done
done


#
# Backup users too
while read HOST USER; do
  ${MYSQL} -bNe "SHOW GRANTS FOR '$USER'@'$HOST';" | 
    sed -e 's/\\\\/\\/g' -e 's/$/;/'
done < <( ${MYSQL} mysql -bNe "SELECT Host, User FROM user;" ) \
     > "${BACKUPDIR}"/"${DATE}"/sql-perms.sql


#
# Housekeeping.  Delete any file older than $RETENTION days
if which tmpwatch &>/dev/null; then
  tmpwatch --mtime $(( 24 * $RETENTION )) "${BACKUPDIR}"
elif which tmpreaper &>/dev/null; then
  tmpreaper --mtime $(( 24 * $RETENTION )) "${BACKUPDIR}"
else
  find "${BACKUPDIR}" -maxdepth 1 -mindepth 1 -mtime +${RETENTION} -exec rm -rf {} \;
fi

