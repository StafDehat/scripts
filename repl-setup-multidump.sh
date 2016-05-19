#!/bin/bash

backupDir="/var/spool/holland/mysqldump/newest/backup_data"
masterHost=""
masterUser=""
masterPass=""
masterPort=3306
slaveUser=""
slavePass=""
MYSQL="mysql -u${slaveUser} -p${slavePass}"


function usage() {
  echo "No usage yet!"
}















function debug() {
  echo "$(date +"%F %T"): $@"
}

function sortDumps() {
  for dumpFile in *.sql.gz; do
    local changeMaster="$( zcat $dumpFile | head -n 50 | grep CHANGE )"
    local binFile=$( cut -d\' -f2 <<<"$changeMaster" )
    local binPos=$( cut -d\= -f3 <<<"$changeMaster" | tr -d ';' )
    echo "$binFile $binPos $dumpFile"
  done | sort -n -k1,1 -k2,2
}

debug "Creating backup of my.cnf"
cp /etc/my.cnf{,.$(date +%F_%T)}

debug "Adding \!include to my.cnf"
tmpFile="$( mktemp )"
sed -i '/^\s*\[mysqld\]/s_$_\n!include '"${tmpFile}"'_' /etc/my.cnf

debug "Creating global-ignore tmpFile config"
echo '[mysqld]' >"${tmpFile}"
echo 'replicate-wild-ignore-table=%.%' >>"${tmpFile}"

firstRun=true
sortDumps | while read LINE; do
  binFile=$( awk '{print $1}' <<<"$LINE" )
  binPos=$( awk '{print $2}' <<<"$LINE" )
  dumpFile=$( awk '{print $3}' <<<"$LINE" )

  if $firstRun; then
    debug "Initializing master to ${binFile}:${binPos}"
    echo $MYSQL -e "CHANGE MASTER TO MASTER_HOST='${masterHost}',
                                MASTER_USER='${masterUser}',
                                MASTER_PASSWORD='${masterPass}',
                                MASTER_PORT=${masterPort},
                                MASTER_LOG_FILE='${binFile}',
                                MASTER_LOG_POS=${binPos};"
    firstRun=false
  fi

  debug "Restarting mysqld to ensure all config files are live"
  service mysqld restart

  doDBs=$( grep replicate-wild-do-table "${tmpFile}" | 
             cut -d\= -f2 |
             cut -d\. -f1 )
  debug "Included DBS: "${doDBs}

  debug "Starting slave until ${binFile}:${binPos}"
  $MYSQL -e "START SLAVE UNTIL MASTER_LOG_FILE='${binFile}',
                               MASTER_LOG_POS=${binPos};"

  debug "Importing ${dumpFile}"
  zcat ${dumpFile} | $MYSQL ${dumpFile/.sql.gz/}

  debug "Adding DB ${dumpFile/.sql.gz/} to replication"
  echo "replicate-wild-do-table=${dumpFile/.sql.gz/}.%" >> "${tmpFile}"
done

debug "Removing temporary !include from my.cnf"
grep -vP "^\!include ${tmpFile}" /etc/my.cnf > "${tmpFile}"
mv -f "${tmpFile}" /etc/my.cnf

debug "Starting slave threads"
$MYSQL -e "START SLAVE;"


