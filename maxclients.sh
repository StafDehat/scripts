#!/bin/bash
# Author: Andrew Howard

declare -a ParPIDs
declare -a ProcNames
dataSrc="ps"

function error()  { echo "$(date +"%F %T") ERROR: $@" >&2; }
function output() { echo "$(date +"%F %T"): $@"; }
function debug()  { echo "$(date +"%F %T"): $@"; }

function usage() {
cat <<EOF
Usage:
	$0 [-s] [-p]
Example:
	$0 -s pmap -n apache2
Arguments:
        -p	Parent PID of pstree
        -n	Name of pstree executable (ie: apache2, or httpd)
	-h	Print this help
        -s SRC	Use 'SRC' for calculations. See SOURCES.
SOURCES:
	smem	
	pmap	
	ps	Pull per-process memory footprint from RSS column of 'ps'
EOF
}

function parseArgs() {
  local invalidUsage=false
  while getopts ":hn:p:s:" arg; do
    case ${arg} in
      h) usage && exit 0;;
      n) ProcNames+=( "${OPTARG}" );;
      p) ParPIDs+=( "${OPTARG}" );;
      s) dataSrc="${OPTARG}";;
      :) error "Option -${OPTARG} requires an argument."
         invalidUsage=true;;
      *) error "Invalid option: -${OPTARG}"
         invalidUsage=true;;
    esac
  done #End arguments
  shift $((${OPTIND} - 1))
  [[ "${invalidUsage}" != "false" ]] && return 1 || return 0
}

function sanitizeArgs() {
  local invalidUsage=false


  # Verify specified PIDs are actually valid PIDs?


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

  # Verify we've implemented the form of reporting they requested
  if [[ "$( type -t ${dataSrc}Report )" != "function" ]]; then
    error "Specified SOURCE (${dataSrc}) not valid"
    invalidUsage=true
  fi

  [[ "${invalidUsage}" != "false" ]] && return 1 || return 0
}

function psReport() {
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

  rootPID="${1}"
  SUM=0
  COUNT=0
  for x in $( ps f --ppid ${rootPID} -o rss= ); do
    SUM=$(( $SUM + $x ))
    COUNT=$(( $COUNT + 1 ))
  done

  MEMPP=$(( $SUM / $COUNT / 1024 ))
  FREERAM=$(( `free | tail -2 | head -1 | awk '{print $4}'` / 1024 ))
  APACHERAM=$(( $SUM / 1024 ))
  APACHEMAX=$(( $APACHERAM + $FREERAM ))

  echo
  echo "Info for the following parent apache process:"
  echo "  $( ps f --pid ${rootPID} -o command= )"
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
}

function smemReport() {
  echo "Smem!!!"
  return 0
}

function pssReport() {
  echo "PSS!!!"
  rootPID="${1}"
  childPIDs="$( ps f --ppid ${rootPID} -o pid= )"

  for childPID in ${childPIDs}; do
    awk '$1 ~ /^Pss:$/ {sum+=$2} END {print sum}' /proc/${childPID}/smaps 
  done | awk '{sum+=$1} END {print sum}'
  
  return 0
}

function pmapReport() {
  if ! which "${dataSrc}" &>/dev/null; then
    error "Unable to find '${dataSrc}' binary."
    exit 2
  fi

  rootPID="${1}"
  childPIDs="$( ps f --ppid ${rootPID} -o pid= )"

  #lsofAll="$( lsof )"
  #lsofNotMe=$( awk '$1 !~ /^'"${commandName}"'$/ {print}' <<<"${lsofAll}" )
  #commandName="$( ps f --ppid ${rootPID} -o comm= | awk '{print $1}' | sort -u )"

  pidsAll=$( ps -A -o pid= | sed 's/\s\s*/\n/g' | sort -nu )
  pidsMe=$( echo ${rootPID} ${childPIDs} | sed 's/\s\s*/\n/g' | sort -nu )
  pidsNotMe=$( comm -13 <(sort <<<"${pidsMe}") <(sort <<<"${pidsAll}") | sort -n )

  sharedLibsAll=$( pmap -d ${pidsNotMe} | sort -u | grep -P '\.so(\..*)?$' )
  sharedLibsMeAlso=$( pmap -d ${pidsMe} | sort -u | grep -P '\.so(\..*)?$' )
  sharedLibsMeOnly=$( comm -13 <( sort <<<"${sharedLibsAll}" ) \
                               <( sort <<<"${sharedLibsMeAlso}" ) )

  # RAM consumption by shared libs that I link to (other procs might too)
  sharedRamMeAll=$( awk '$3 ~ /^r[w-][x-]--$/ {sum+=$2} END {print sum}' <<<"${sharedLibsMeAlso}" )
  # RAM consumption by shared libs that *only* I link to
  sharedRamMeOnly=$( awk '$3 ~ /^r[w-][x-]--$/ {sum+=$2} END {print sum}' <<<"${sharedLibsMeOnly}" )
  # RAM consumption by shared libs that I use, but other procs also use
  sharedRamMeAlso=$(( sharedRamMeAll - sharedRamMeOnly ))

  rootProcMemTotal=$( pmap -d ${rootPID} | grep -oP 'writeable/private:[\s\d]+' | grep -oP '\d+' )
  baseline=$(( ${rootProcMem} + ${sharedRamMeOnly} ))
             # Exclusive memory of root proc:
             $( pmap -d ${rootPID} | grep -oP 'writeable/private:[\s\d]+' | grep -oP '\d+' ) +
             # Mem consumption from shared objects loaded by this pstree
             $( { echo ${rootPID}; ps f --ppid ${rootPID} -o pid=; } | 
                  xargs pmap -d | grep -oP 'shared:[\s\d]+' | grep -oP '\d+'
             )
           ))
  

  ps f --ppid ${rootPID} -o pid= | 
    xargs pmap -d | grep -P '\.so(\..*)?$' | awk '{sum+=$2} END {print sum}'
  
  return 0
}


# Check for proper usage 
invalidUsage=false
parseArgs $@ || invalidUsage=true
sanitizeArgs || invalidUsage=true
if [[ "${invalidUsage}" != "false" ]]; then
  echo "Failed usage."
  usage && exit 1
fi

# Report on each PID
for aPID in ${ParPIDs[@]}; do
  ${dataSrc}Report ${aPID}
done


