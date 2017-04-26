#!/bin/bash
# Author: Andrew Howard
# Apache only loads shared objects once, but every child process will 
# report memory as if it loaded the object itself. This means every process 
# is going to over-report its resident memory usage. This means you could 
# have a 4GB system that appears to have 6GB RAM in-use by apache. There's 
# no known way to get a precise value of actual RAM used by an apache 
# process (if you know one, please lodge a git issue).
# However, since the error is on both sides of the division, it cancels out. 
# This means the error only comes into effect in calculating how many 
# processes will use up the remaining, unused RAM, which means we'll err on 
# the side of caution by setting the value too low.  The estimate gets more 
# accurate as apache claims more RAM.
# Also note, the script has been updated to support multiple apache 
# instances on a single server. Each instance calculates its own MaxClients 
# value completely unaware of the other instance configurations, save for 
# the memory currently in use by those instances. If they were aware of each 
# other, I'd have to give MaxClients recommendations as a function of the 
# other, and it wouldn't make sense to any techs using the script.  This 
# almost never actually comes into effect.  In 99% of cases, there's only 
# one apache instance.


declare -a ParPIDs
declare -a ProcNames
dataSrc="pmon"

function error()  { echo "$(date +"%F %T"): $@" >&2; }
function output() { echo "$(date +"%F %T"): $@"; }
function debug()  { echo "$(date +"%F %T"): $@"; }

function usage() {
cat <<EOF
Usage: $0 [-s] [-p]

Example:

Arguments:
        -p	Parent PID of pstree
        -n	Name of pstree executable (ie: apache2, or httpd)
	-h	Print this help
        -s SRC	Use 'SRC' for calculations. See SOURCES.

SOURCES:
	smem	
	pmon	
	ps	Pull per-process memory footprint from RSS column of 'ps'
EOF
}

function parseArgs() {
  local invalidUsage=false
  while getopts ":hp:s:" arg; do
    case ${arg} in
      h) usage && exit 0;;
      n) ProcNames+=( "${OPTARG}" );;
      p) ParPIDs+=( "${OPTARG}" );;
      s) dataSrc="${OPTARG}";;
      :) error "ERROR: Option -${OPTARG} requires an argument."
         invalidUsage=true;;
      *) error "ERROR: Invalid option: -${OPTARG}"
         invalidUsage=true;;
    esac
  done #End arguments
  shift $((${OPTIND} - 1))
  [[ "${invalidUsage}" != "false" ]] && return 1 || return 0
}

function sanitizeArgs() {
  local invalidUsage=false
  local -a validSources
  validSources+=( "pmon" )
  validSources+=( "smem" )
  validSources+=( "ps" )
  # Compare validSources[@] to validSources[@].remove(dataSrc)
  # If identical, you didn't pick a valid source.  
  if [[ "${validSources[@]##${dataSrc}}" == "${validSources[@]}" ]]; then
    error "Specified SOURCE (${dataSrc}) not valid"
    invalidUsage=true
  fi


  # Verify specified PIDs are actually valid PIDs


  # Identify parent PIDs of named executables
  for ProcName in ${ProcNames[@]}; do
    local childList=$( pidof ${ProcName} )
    local parentList=$( comm -12 <( ps -o ppid= -p ${childList} 2>/dev/null ) \
                                 <( ps -o pid= -p ${childList} 2>/dev/null ) )
    if grep -q '^\s*$' <<<"${parentList}"; then
      error "Unable to identify PID of ${ProcName} - skipping that one"
    else
      for parentPid in $parentList; do
        ParPIDs+=( ${parentPid} )
      done
    fi
  done

  # Ensure at least 1x process tree was specified
  if [[ ${#ParPIDs[@]} -eq 0 ]]; then
    error 'Must define at least 1 valid process name or PID'
    invalidUsage=true
  fi
  
  [[ "${invalidUsage}" != "false" ]] && return 1 || return 0
}


function pmonTree() {
  return 0


}




 
for ParPID in $PARENTPIDS; do
  SUM=0
  COUNT=0
  for x in $( ps f --ppid $ParPID -o rss= ); do
    SUM=$(( $SUM + $x ))
    COUNT=$(( $COUNT + 1 ))
  done
 
  MEMPP=$(( $SUM / $COUNT / 1024 ))
  FREERAM=$(( `free | tail -2 | head -1 | awk '{print $4}'` / 1024 ))
  APACHERAM=$(( $SUM / 1024 ))
  APACHEMAX=$(( $APACHERAM + $FREERAM ))
 
  (
  echo
  echo "Info for the following parent apache process:"
  echo "  "`ps f --pid $ParPID -o command | tail -n +2`
  echo
  echo "Current # of apache processes:        $COUNT"
  echo "Average memory per apache process:    $MEMPP MB"
  echo "Free RAM (including cache & buffers): $FREERAM MB"
  echo "RAM currently in use by apache:       $APACHERAM MB"
  echo "Max RAM available to apache:          $APACHEMAX MB"
  echo 
  echo "Theoretical maximum MaxClients:  $(( $APACHEMAX / $MEMPP ))"
  echo "Recommended MaxClients:          $(( $APACHEMAX / 10 * 9 / $MEMPP ))"
  echo
  )
done

