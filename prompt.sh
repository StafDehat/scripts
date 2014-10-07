#!/bin/bash

# Author: Andrew Howard

# Set the terminal, so people stop complaining about the hash as their prompt
# regular colors
K="\[\033[0;30m\]"    # black
R="\[\033[0;31m\]"    # red
G="\[\033[0;32m\]"    # green
Y="\[\033[0;33m\]"    # yellow
B="\[\033[0;34m\]"    # blue
P="\[\033[0;35m\]"    # purple
C="\[\033[0;36m\]"    # cyan
W="\[\033[0;37m\]"    # white
# emphasized (bolded) colors
EMK="\[\033[1;30m\]"
EMR="\[\033[1;31m\]"
EMG="\[\033[1;32m\]"
EMY="\[\033[1;33m\]"
EMB="\[\033[1;34m\]"
EMP="\[\033[1;35m\]"
EMC="\[\033[1;36m\]"
EMW="\[\033[1;37m\]"
# background colors
BGK="\[\033[40m\]"
BGR="\[\033[41m\]"
BGG="\[\033[42m\]"
BGY="\[\033[43m\]"
BGB="\[\033[44m\]"
BGP="\[\033[45m\]"
BGC="\[\033[46m\]"
BGW="\[\033[47m\]"
# Other colors
NORMAL="\[\033[m\]"

# Prompt settings
if [ `id -u` = 0 ]; then
  export PS1="$EMG\u$EMB@$EMR\h$EMB[$EMP\W$EMB]#$NORMAL "
else
  export PS1="$EMG\u$EMB@$EMR\h$EMB[$EMP\w$EMB]\$$NORMAL "
fi
export PS2="$EMB>$NORMAL "

