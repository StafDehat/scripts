#!/bin/bash
# Author: Andrew Howard
# Purpose: Take multiple mysqldump files, all from the same master, but
#   all at different master log positions.  Import them sequentially,
#   including each DB in replication as it's imported.
#   Basically it automates a replication setup from a backup taken with
#   Holland, using the settings:
#   bin-log-position = yes
#   file-per-database = yes


function usage() {
  echo "Usage: $0 \\"
  echo "  [-h] -d backupDir \\"
  echo "  -H masterHost -U masterUser -P masterPass [-T masterPort] \\"
  echo "  -u slaveUser -p slavePass"
  echo "Example:"
  echo "  # $0 \\"
  echo "      -d /var/spool/holland/mysqldump/newest/backup_data \\"
  echo "      -H 1.2.3.4 \\"
  echo "      -U repl \\"
  echo "      -P abc123def \\"
  echo "      -u root \\"
  echo "      -u turbographics"
  echo "Arguments:"
  echo "  -d X  Local directory containing *.sql.gz mysqldumps."
  echo "  -h    Print this help"
  echo "  -H X  Hostname/IP of MySQL master (remote)."
  echo "  -t X  Optional (default 3306).  TCP port for connecting to MySQL master (remote)."
  echo "  -p X  Password for connecting to MySQL slave (localhost)."
  echo "  -P X  Password for connecting to MySQL master (remote)."
  echo "  -u X  Username for connecting to MySQL slave (localhost)."
  echo "  -U X  Username for connecting to MySQL master (remote)."
}
function debug() {
  echo "$(date +"%F %T"): $@"
}
function output() {
  echo "$(date +"%F %T"): $@"
}


invalidUsage=false
backupDir=""
masterHost=""
masterUser=""
masterPass=""
masterPort=3306
slaveUser=""
slavePass=""
while getopts ":d:hH:p:P:T:u:U:" arg; do
  case $arg in
    d) backupDir="$OPTARG";;
    h) usage && exit 0;;
    H) masterHost="$OPTARG";;
    p) slavePass="$OPTARG";;
    P) masterPass="$OPTARG";;
    T) masterPort="$OPTARG";;
    u) slaveUser="$OPTARG";;
    U) masterUser="$OPTARG";;
    :) output "ERROR: Option -$OPTARG requires an argument."
       invalidUsage=true;;
    *) output "ERROR: Invalid option: -$OPTARG"
       invalidUsage=true;;
  esac
done #End arguments
shift $(($OPTIND - 1))

for ARG in backupDir masterHost masterUser masterPass slaveUser slavePass; do
  if [ -z "${!ARG}" ]; then
    output "ERROR: Must define $ARG as argument"
    invalidUsage=true
  fi
done
if ! grep -qP '^[0-9]+$' <<<"$masterPort"; then
  output "ERROR: masterPort must be numeric"
  invalidUsage=true
elif [[ $masterPort -gt 65535 ]]; then
  output "ERROR: masterPort must be >=1 and <=65535"
  invalidUsage=true
fi
if $invalidUsage; then
  usage && exit 1
fi


tmpFile="$( mktemp )"
function cleanup {
  rm -f $tmpFile
  stty echo
  exit
}
trap 'cleanup' 1 2 9 15 17 19 23 EXIT


MYSQL="mysql -u${slaveUser} -p${slavePass} --skip-column-names"
slaveVersion=$( $MYSQL -e "select @@version;" )
masterVersion=$( mysql -u${masterUser} \
                       -p${masterPass} \
                       --protocol=TCP \
                       -h ${masterHost} \
                       -P ${masterPort} \
                       --skip-column-names \
                       -e "select @@version;" )
if [[ -z "${slaveVersion}" ]]; then
  output "ERROR: Unable to connect to local MySQL slave instance."
  exit
fi
if [[ -z "${masterVersion}" ]]; then
  output "ERROR: Unable to connect to remote MySQL master instance."
  exit
fi


function sortDumps() {
  for dumpFile in *.sql.gz; do
    local changeMaster="$( zcat $dumpFile | head -n 50 | grep CHANGE )"
    if [[ -z "$changeMaster" ]]; then
      output "ERROR: Unable to find CHANGE MASTER line in $dumpFile"
      exit 2
    fi
    local binFile=$( cut -d\' -f2 <<<"$changeMaster" )
    local binPos=$( cut -d\= -f3 <<<"$changeMaster" | tr -d ';' )
    echo "$binFile $binPos $dumpFile"
  done | sort -n -k1,1 -k2,2
}

debug "Creating backup of my.cnf"
cp /etc/my.cnf{,.$(date +%F_%T)}

debug "Adding \!include to my.cnf"
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
    $MYSQL -e "CHANGE MASTER TO MASTER_HOST='${masterHost}',
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

#debug "Starting slave threads"
#$MYSQL -e "START SLAVE;"

debug "You should be able to run 'START SLAVE' now."


