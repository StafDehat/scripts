#!/bin/bash
# Author: Andrew Howard
# This script prints the absolute path to every file that's included in the
# apache config.  It assumes that the apache_root is either:
#   /etc/httpd
#   /etc/apache2
# Also assumes the SERVER_CONFIG_FILE is either:
#   /etc/httpd/conf/httpd.conf
#   /etc/apache2/apache2.conf

function debug() {
  while read LINE; do
    echo "$(date +%F_%T) ${LINE}" >&2
  done < <(echo "${@}")
}

#!/bin/bash
function getApacheConfigFile() {
  rootPid="${1}"
  ls -1 /etc/httpd/conf/httpd.conf /etc/apache2/apache2.conf 2>/dev/null | head -n 1
  return 0
}

#!/bin/bash
function getApacheRootDir() {
  rootPid="${1}"
  ls -1d /etc/httpd /etc/apache2 2>/dev/null | head -n 1
  return 0
}

#!/bin/bash
function getApacheRootPids() {
  local httpProcs
  local allHttpPids
  local httpParentPids

  # Dump relevant 'ps' lines in a var, so we don't run 'ps' 50 times
  httpProcs=$( ps -ef | grep '[a]pache\|[h]ttp' )

  # Grab the PID of every process calling itself apache/apache2/httpd
  allHttpPids=$( pidof httpd apache{,2} | xargs -n 1 echo )

  # From those PIDs, grab the parent PID of each.
  httpParentPids=$(
    for childPid in ${allHttpPids}; do
      awk '$2 ~ /^'${childPid}'$/ {print $3}' <(echo "${httpProcs}")
    done
  )
  # Anything that's both an apache proc, and the parent of an apache proc, should
  #   be an apache daemon - all the children are worker procs.
  debug "Detected the following apache processes:" ${allHttpPids}
  debug "Those PIDs have the following parent processes:" ${httpParentPids}
  apacheDaemonPids=$( comm -12 <( echo "${allHttpPids}" | sort ) \
                               <( echo "${httpParentPids}" | sort ) | sort -n )
  debug "These PIDs appear in both lists, so must be an apache daemon:" ${apacheDaemonPids}
  echo "${apacheDaemonPids}"
}

#!/bin/bash
function getIncludedApacheConfig() {
  # Arguments
  local rootDir="${1}"
  local rootConf="${2}"

  # Initialization
  local oldList=""
  local newList=""
  local newFinds="" # Verbatim Include targets (ie: maybe "*.conf")
  local newFiles="" # Canonicalized config files
  local iteration=0
  local oldPWD="$(pwd)"

  # Just in case vars were passed with relative paths, canonicalize:
  # Also, verify SERVER_ROOT and SERVER_CONFIG_FILE actually exist
  debug "SERVER_ROOT passed to ${FUNCNAME}: ${rootDir}"
  rootDir=$( readlink -f "${rootDir}" 2>/dev/null | head -n 1 )
  if [[ -z "${rootDir}" || ! -d "${rootDir}" ]]; then
    debug "SERVER_ROOT passed to ${FUNCNAME} (${rootDir}) does not exist."
    return 0
  fi
  debug "Canonicalized SERVER_ROOT: ${rootDir}"
  debug "Changing PWD to ${rootDir}, to allow for relative paths in Include configs."
  cd "${rootDir}"
  debug "SERVER_CONFIG_FILE passed to ${FUNCNAME}: ${rootConf}"
  rootConf=$( readlink -f "${rootConf}" 2>/dev/null | head -n 1 )
  if [[ -z "${rootConf}" || ! -r "${rootConf}" ]]; then
    debug "SERVER_CONFIG_FILE passed to ${FUNCNAME} (${rootConf}) is not readable."
    return 0
  fi
  debug "Canonicalized SERVER_CONFIG_FILE: ${rootConf}"

  # Start with just the root apache config file:
  newList="${rootConf}"
  newFinds="${rootConf}"
  while [[ -n "${newFinds}"  ]]; do
    iteration=$(( iteration + 1 ))
    debug "Beginning loop iteration # ${iteration}."
    debug "(${iteration}) Files checked in previous iterations:"
    debug "${oldList}"
    # We're only checking the *new* stuff, to avoid endlessly grep'ing httpd.conf
    toSearch=$(
      # If its in oldList, we already checked it for includes
      # If not, we need to note all its includes
      comm -13 <(echo "${oldList}" | sort) \
               <(echo "${newList}" | sort)
    )
    debug "(${iteration}) Files to be checked this iteration:"
    debug "${toSearch}"

    # Identify all Include lines in ${toSearch} files
    # Use a while, to allow for whitespace in filenames
    newFinds=$(
      while read INCLUDE; do
        sed -n 's/^[[:space:]]*include\(optional\)\?[[:space:]]\+\([^#]\+\)\(#.*\)\?$/\2/Ip' "${INCLUDE}"
      done < <(echo "${toSearch}")
    )
    debug "(${iteration}) Verbatim Include targets identified this iteration:"
    debug "${newFinds}"

    # Canonicalize the newly-identified lines
    newFiles=$( 
      while read includeLine; do
        [[ -z "${includeLine}" ]] && continue
        debug "(${iteration}) Canonicalizing/Expanding ${includeLine}"
        # Attempt to handle both whitespace and globbing
        # The "set +f" and for-loop should expand globbing.
        # Setting IFS=\r should prevent whitespace from breaking the for-loop
        set +f  #Ensure globbing enabled
        IFS=$( echo -e '\r' )
        for includeFile in ${includeLine}; do
          readlink -f ${includeFile}
        done
        # End whitespace/globbing handling
      done < <(echo "${newFinds}")
    )
    debug "(${iteration}) Canonicalized Include targets:"
    debug "${newFiles}"

    # Save newList as oldList so we can diff em to see which ones we just found
    # ie: Which ones to grep
    oldList="${newList}"
    # And record newList as oldList+newFiles
    newList=$(
      { 
        echo "${oldList}";
        echo "${newFiles}";
      } |
        sed '/^[[:space:]]*$/d' | # Nuke blank lines
        sort -u                   # De-dupe
    )
  done

  # Restore the original CWD
  debug "Returning to original PWD (${oldPWD})"
  cd "${oldPWD}"

  debug "Absolute path to all included config files is as follows:"
  debug "${newList}"
  echo "${newList}"
}

getIncludedApacheConfig $(getApacheRootDir) $(getApacheConfigFile)

