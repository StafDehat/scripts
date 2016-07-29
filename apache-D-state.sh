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
  trap 'cleanup' 1 2 9 15 17 19 23 EXIT
fi

DATE=$( date +%F-%T )
LOGDIR=/var/log/ahoward

ps -eo ppid,pid,user,stat,pcpu,comm,wchan:32 >$LOGDIR/ps.$DATE
sar -n TCP,ETCP 1 30 >$LOGDIR/sar.tcp.$DATE &
ParPID=$( ps -C httpd u | awk '$1 ~ /root/ {print $2}' )
timeout 300 strace -crfp ${ParPID} &> "${LOGDIR}/strace-sum.${DATE}" &


# Test if any apache procs are in D state
DPIDS=$( ps u -C httpd | awk '$8 ~ /D/ {print $2}' )
if [[ -n "${DPIDS}" &&
      "${DPIDS}" -gt 5 ]]; then
  # If so, log way more stuff

  # Force a stack trace to /var/log/messages
  echo w > /proc/sysrq-trigger

  # Save all apache pids
  #PIDS=$( pidof httpd )
  # Can't use pidof, 'cause we'd get the root proc too
  PIDS=$( ps -U apache u | awk '{print $2}' | tail -n +2 )

  # Strace all the apache procs for file opens and network connections
  SDIR="${LOGDIR}/strace.${DATE}"
  mkdir "${SDIR}"
  for pid in ${PIDS}; do
    strace -rfp $pid -e trace=open,read,write,network -s 500 &>$SDIR/$pid &
  done

  # Log an lsof for all apache procs
  LSDIR="${LOGDIR}/lsof.${DATE}"
  mkdir "${LSDIR}"
  for pid in ${PIDS}; do
    lsof -p $pid > "${LSDIR}/${pid}"
  done
fi

tmpwatch -m 24h "${LOGDIR}"

