#!/bin/bash

#
# Usage: checknow.sh config-file-1 config-file-2 ...

# Colours!
K="\033[0;30m"    # black
R="\033[0;31m"    # red
G="\033[0;32m"    # green
Y="\033[0;33m"    # yellow
B="\033[0;34m"    # blue
P="\033[0;35m"    # purple
C="\033[0;36m"    # cyan
W="\033[0;37m"    # white
EMK="\033[1;30m"
EMR="\033[1;31m"
EMG="\033[1;32m"
EMY="\033[1;33m"
EMB="\033[1;34m"
EMP="\033[1;35m"
EMC="\033[1;36m"
EMW="\033[1;37m"
NORMAL=`tput sgr0 2> /dev/null`

# Some environment variables for Nagios
CHKCMDCFGFILE=/etc/nagios/objects/commands.cfg
LIBEXEC=/usr/lib64/nagios/plugins
MONDIR=/home/nagios/monitors
CMDFILE=/var/nagios/rw/nagios.cmd
#REMDIR=/usr/local/nagios/etc/monitoring/remote
#SLAVEDIR=/usr/local/nagios/etc/monitoring/slaves
REMOTE=0


# Command-line arguments
SUBMIT=0
VERBOSE=0
while getopts ":hsv" arg
do
  case $arg in
    h  ) # Print help
         echo "Usage: $0 [OPTION] FILE [FILE...]"
         echo "Execute the monitor defined in FILE"
         echo "Example: $0 -v http.cfg raid_lin.cfg"
         echo ""
         echo "Options:"
         echo "  -h     Print this help menu"
         echo "  -s     Submit results to nagios daemon"
         echo "  -v     Verbose.  Print check results instead of just"
         echo "         Success, Warning, Critical, or Unknown"
         exit 1;;
    s  ) # Set submit flag, so results are imported to nagios
         SUBMIT=1
         echo -e "${EMC}Check results will be submitted to nagios${NORMAL}";;
    v  ) # Set verbose flag, for detailed check results
         VERBOSE=1;;
    *  ) # Default
         echo "Usage: $0 [OPTION] FILE [FILE...]"
         echo "For more information: $0 -h"
         exit 1;;
  esac
done
shift $(($OPTIND - 1))


# Variable arity!  Check each cfg file passed on command line
# CFG=D-Free.cfg
for CFG in $@; do
  # Verify file exists
  if [ ! -f $CFG ]; then
    echo -e "${EMY}Skipping file $CFG: File does not exist${NORMAL}"
  # Make sure this is a service monitor, not a host config.
  elif [ `grep -cE '^\s*define\s*service\s*\{' $CFG` -ne 1 ]; then
    echo -e "${EMY}Skipping file $CFG: Not a single monitor definition${NORMAL}"
  else
    CFG=`echo "$( readlink -f "$( dirname "$CFG" )" )/$( basename "$CFG" )"`
    if [[ "$CFG" =~ "$MONDIR" ]]; then
      REMOTE=0
      CFGDIR=$MONDIR
    elif [[ "$CFG" =~ "$REMDIR" ]]; then
      REMOTE=1
      CFGDIR=$REMDIR
    fi

    # CHKCMD=check_disk_win!OLYMPUS!1.3.6.1.4.1.9600.1.1.1.1.5.2.68.58!10!10
    CHKCMD=`sed -n 's/^\s*check_command\s*//p' $CFG`

    # CMD=check_disk_win
    CMD=`echo $CHKCMD | cut -d! -f1`

    # ARGS=OLYMPUS!1.3.6.1.4.1.9600.1.1.1.1.5.2.68.58!10!10
    ARGS=""
    if [ `echo $CHKCMD | grep -c '!'` -gt 0 ]; then
      ARGS=`echo $CHKCMD | cut -d! -f2-`
    fi

    # CHKCMDTMPL=check_snmp -H $HOSTADDRESS$ -o $ARG2$ -w $ARG3$:100 -c $ARG4$:100 -C $ARG1$
    CHKCMDTMPL=`grep -vE '^\s*\#|^\s*$' $CHKCMDCFGFILE | \
    grep -E 'command_name|command_line' | \
    grep -A 1 -E '^\s*command_name\s*'$CMD'\s*$' | \
    sed -n 's/^\s*command_line\s*\$USER1\$\///p'`

    # Determine IP of server
    SERVERNAME=`grep -E '^\s*host_name' $CFG | awk '{print $2}'`
    IPADDR=`grep -E '^\s*address' $CFGDIR/$SERVERNAME/$SERVERNAME.cfg | awk '{print $2}'`

    # Count the arguments
    ARGC=`echo $ARGS | sed 's/\!/\n/g' | wc -l`

    # Build check_command, replacing ARG$x with actual values
    x=1
    CHKCMD=$CHKCMDTMPL
    CHKCMD=$(echo $CHKCMD | sed 's/\$HOSTADDRESS\$/'$IPADDR'/')
    if [ -n "$ARGS" ]; then
      while read LINE; do
        # Replaced this line, because sed had issues with ARGs containing '/'
        # CHKCMD=$(echo $CHKCMD | sed 's/\$ARG'$x'\$/'"$LINE"'/')
        CHKCMD=$(echo -n $CHKCMD | sed 's/\$ARG'$x'\$.*$//'; echo -n $LINE; echo $CHKCMD | sed 's/^.*\$ARG'$x'\$//')
        x=$(( x + 1 ))
      done < <(echo $ARGS | sed -e 's/\!/\n/g' -e 's/"/\\"/g')
    fi

#    if [ $REMOTE -eq 0 ]; then
#      # Run check from Atma, unless check is to be run remotely only
      if [ $VERBOSE -eq 0 ]; then
        echo "sudo -u nagios $LIBEXEC/$CHKCMD" | /bin/bash &>/dev/null
        RET=$?
        if [ $RET -eq 0 ]; then
          echo -e "Checking $CFG from Atma: ${EMG}Success${NORMAL}"
        elif [ $RET -eq 1 ]; then
          echo -e "Checking $CFG from Atma: ${EMY}Warning${NORMAL}"
        elif [ $RET -eq 2 ]; then
          echo -e "Checking $CFG from Atma: ${EMR}Critical${NORMAL}"
        else
          echo -e "Checking $CFG from Atma: ${EMR}Unknown${NORMAL}"
        fi
      else
        echo "Checking $CFG from Atma:"
        echo -n "  "
        echo "sudo -u nagios $LIBEXEC/$CHKCMD" | /bin/bash
      fi
#    else
#      echo "Remote monitors cannot be checked from Atma directly - skipping this step"
#    fi

#    # Run check from a slave
#    if [ $REMOTE -eq 1 ]; then
#      SLAVE=belmont
#    else
#      cd $SLAVEDIR
#      SLAVE=`find . -name $SERVERNAME | cut -d/ -f2`
#      if [ -z $SLAVE ]; then
#        SLAVE=`echo * | cut -d\  -f1`
#      fi
#    fi
#    cd $OLDPWD
#    if [ $VERBOSE -eq 0 ]; then
#      ssh -l nagios $SLAVE "$LIBEXEC/$CHKCMD" &>/dev/null
#      RET=$?
#      if [ $RET -eq 0 ]; then
#        echo -e "Checking $CFG from $SLAVE: ${EMG}Success${NORMAL}"
#      elif [ $RET -eq 1 ]; then
#        echo -e "Checking $CFG from $SLAVE: ${EMY}Warning${NORMAL}"
#      elif [ $RET -eq 2 ]; then
#        echo -e "Checking $CFG from $SLAVE: ${EMR}Critical${NORMAL}"
#      else
#        echo -e "Checking $CFG from $SLAVE: ${EMR}Unknown${NORMAL}"
#      fi
#    else
#      echo "Checking $CFG from $SLAVE:"
#      echo -n "  "
#      ssh -l nagios $SLAVE "$LIBEXEC/$CHKCMD"
#    fi

    if [ $SUBMIT -eq 1 ]; then
      # HOST=$SERVERNAME
      SERVICE=`grep service_description $CFG | awk '{print $2}'`
      # STATUS=$RET
      INFO="Forced manual check"
      echo "[`date +%s`] PROCESS_SERVICE_CHECK_RESULT;$SERVERNAME;$SERVICE;$RET;$INFO" >> $CMDFILE
    fi
  fi
done

