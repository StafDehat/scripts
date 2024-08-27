#!/bin/bash

# Author: Andrew Howard
# Lots of thanks to Alan Hicks for suggesting "ip rule" to bypass the 'main'
#   routing table.

USERNAME="john.doe"
EXE="/opt/cisco/anyconnect/bin/vpn"
HOST="vpnhost.example.com"


function cleanup() {
  stty echo
}
trap 'cleanup && exit 0' 1 2 9 15 19 23
trap 'cleanup && exit 0' 1 2 9 15 19 23

function usage() {
  echo "Usage: $0 [connect|start|disconnect|stop|status]"
  echo "Commands:"
  echo "  connect|start"
  echo "    Initiate a VPN connection"
  echo "  disconnect:stop"
  echo "    Terminate an existing VPN connection"
  echo "  status"
  echo "    RTFM"
  echo "  help"
  echo "    Print this info"
}

function sudo-auth() {
  SUDO=""
  if [[ $( id -u ) -ne 0 ]]; then
    SUDO="sudo"
    ${SUDO} -v
  fi
}

function routeTableExists() {
  local NAME="${1}"
  local tables=$( grep -vP '^\s*#' /etc/iproute2/rt_tables |
                    awk '{print $2}' )
  if grep -qP "^${NAME}$" <<<"${tables}"; then
    return 0
  fi
  return 1
}

function addRouteTable() {
  local NAME="${1}"

  # Build a list of all routing tables (indexes & names)
  local tables=$(
    (
      ip route show table all |
        grep -oP '\s+table\s+[^\s]+\s' |
        sort -u |
        awk '{print $2}' 
      # Avoid all tables that have names, too
      grep -vP '^\s*#' /etc/iproute2/rt_tables |
        awk '{print $2}' 
    ) | sort -u
  )
  # Map names to numbers
  tables=$( 
    for table in $tables; do
      if grep -qP '^\d+$' <<<"$table"; then
        # Already a numerical table.  Use it as-is.
        echo $table
      else
        # Named table - look it up
        grep -vP '^\s*#' /etc/iproute2/rt_tables |
          awk '$2 ~ /^'"$table"'$/ {print $1}'
      fi
    done | sort -n
  )
  # Find an unused routing table index
  local index=1
  while true; do
    if ! grep -qP "^\s*${index}\s*$" <<<"${tables}"; then
      break
    fi
    index=$(( $index + 1 ))
  done
  # Name it "$NAME" (ie: "$HOST")
  echo -e "${index}\t${NAME}" >> /etc/iproute2/rt_tables
}

function connect() {
  if ! routeTableExists "${HOST}"; then
    addRouteTable "${HOST}"
  fi

  # Blank our own route table
  ip route flush table "${HOST}"

  # Copy all current static routes into our custom routing table
  dests=$( ip route | awk '$1 !~ /default/ {print $1}' )
  oldRoutes=()
  for dest in $dests; do
    oldRoutes+=( "$( ip route save "${dest}" | xxd )" )
  done
  for oldRoute in "${oldRoutes[@]}"; do
    # How to do this into an alternate table?
    ip route restore < <( xxd -r <<<"$oldRoute" )
  done

  # Connect
  sudo-auth
  read -p "Enter PIN+RSA: " -s RSA
  printf "${USERNAME}\n${RSA}\ny" | ${SUDO} "${EXE}" -s connect ${HOST}

  # Use our custom table for our old static routes
  for dest in $dests; do
    ip rule add to ${dest} lookup "${HOST}"
  done
}

# Handle command-line args
ACTION=""
if [[ $# -eq 0 ]]; then
  ACTION="connect"
elif [[ $# -eq 1 ]]; then
  ACTION="${1}"
elif [[ $# -gt 1 ]]; then
  echo "Error: Too many arguments (expected <=1, got $@)"
  usage
  cleanup && exit 0
fi

# Do something useful
case "${ACTION}" in
  connect|start)
    connect
  ;;
  disconnect|stop)
    sudo-auth
    ${SUDO} "${EXE}" -s disconnect
  ;;
  status)
    ${SUDO} "${EXE}" -s status
  ;;
  help)
    usage
    cleanup && exit 0
  ;;
  *)
    echo "Error: Invalid argument (${1})"
    usage
    cleanup && exit 0
  ;;
esac

