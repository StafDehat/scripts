#!/bin/bash
# Author: Andrew Howard
# https://github.rackspace.com/SupportTools/tvs

script=/root/iot-control.sh
project=$( basename "${script}" )
pidFile="/var/run/${project}.pid"
dir=$( dirname "${script}" )

DEBUG=true
function debug() {
  logger -t "${project}" "${project}: $@"
  if [[ "$DEBUG" != "true" ]]; then
    return 0
  fi
  echo -e "\n$@\n"
}

function usage() {
  cat <<"EOF"
Usage:
  ./bash-daemon.sh (start|stop|restart|condrestart)
EOF
}

function start() {
  status
  servStatus=$?
  if [[ $servStatus -eq 0 ]]; then
    # Already running.  Yay?
    debug "Attempted to start, but already running."
    return 0
  fi
  if [[ $servStatus -ge 2 ]]; then
    # Broken state.  Fail.
    debug "Attempted to start, but failed."
    return 1
  fi
  # Not running - attempt to start
  debug "Starting ${project}..."
  "${script}" &
  lastPID=$!
  echo $lastPID > "${pidFile}"
  disown $lastPID
  debug "Started ${project} with PID $lastPID"
  status; return $?
}


function status() {
  # Return codes:
  # 0 = Process running
  # 1 = Process stopped
  # 2 = Process running, but no pidfile exists
  # 3 = Pidfile exists, but no process found
  # 4 = Process running, pidfile exists, but PID doesn't match
  # 5 = Unknown, unexpected status
  procPID="$( pidof -o $$ -x "${project}" )"
  if [[ -n "${procPID}" ]]; then
    # There's a process
    if [[ -e "${pidFile}" ]]; then
      # pidFile exists
      if grep -qP "$( cat $pidFile )" <<<"${procPID}"; then
        # Expected PID matches running proc
        debug "${project} running as process ID ${procPID}"
        return 0
      else
        # Expected PID differs from running proc
        debug "${project} running as unexepected PID: ${procPID} != $(cat "${pidFile}")"
        return 4
      fi
    else
      # pidFile doesn't exist
      debug "${project} running, but no pid file exists"
      return 2
    fi
  else
    # There's no process
    if [[ -e "${pidFile}" ]]; then
      # pidFile exists
      debug "${project} is stopped, but pidfile exists"
      return 3
    else
      # pidFile doesn't exist
      debug "${project} is stopped"
      return 1
    fi
  fi
  debug "Status unknown - sorry"
  return 5
}


function stop() {
  # Return codes:
  # 0 = Process running
  # 1 = Process stopped
  # 2 = Process running, but no pidfile exists
  # 3 = Pidfile exists, but no process found
  # 4 = Process running, pidfile exists, but PID doesn't match
  status
  servStatus=$?
  if [[ $servStatus -eq 1 ]]; then
    debug "Attempted stop, but already stopped"
    return 0
  fi
  # Shutdown the process(es)
  if [[ $servStatus -eq 0 ||
        $servStatus -eq 2 ||
        $servStatus -eq 4 ]]; then
    debug "Shutting down ${project}"
    # Attempt graceful kill
    procPID="$( pidof -o $$ -x "${project}" )"
    debug "Attempting kill 15 of: $procPID"
    timeout 10s kill ${procPID}
    sleep 2
    # Kill harder
    procPID="$( pidof -o $$ -x "${project}" )"
    debug "Attempting kill 9 of: $procPID"
    timeout 5s kill -9 ${procPID}
    sleep 2
  fi
  # Clean up the PID file
  if [[ $servStatus -eq 0 ||
        $servStatus -eq 3 ||
        $servStatus -eq 4 ]]; then
    debug "Deleting pid file"
    rm -f "${pidFile}"
  fi
  status
  servStatus=$?
  # Report the outcome
  if [[ $servStatus -eq 1 ]]; then
    return 0
  fi
  debug "Error stopping ${procBin}"
  return 1
}


function condrestart() {
  if ! status &>/dev/null; then
    debug "Unhealthy status - attempting restart"
    stop
    sleep 5
    start
  fi
}


cd "${dir}"
case "${1}" in
  start)       start ;;
  stop)        stop ;;
  status)      status ;;
  condrestart) condrestart ;;
  *)           usage ;;
esac




