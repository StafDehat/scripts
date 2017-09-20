#!/bin/bash
# Author: Andrew Howard

function colorize() {
  local K
  local R
  local G
  local Y
  local B
  local P
  local C
  local W
  local EMK
  local EMR
  local EMG
  local EMY
  local EMB
  local EMP
  local EMC
  local EMW
  local NORMAL
  local color="${1}"

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

  shift 1
  case "${color}" in 
    "black")	echo -e "${K}${@}${NORMAL}";;
    "red")	echo -e "${R}${@}${NORMAL}";;
    "green")	echo -e "${G}${@}${NORMAL}";;
    "yellow")	echo -e "${Y}${@}${NORMAL}";;
    "blue")	echo -e "${B}${@}${NORMAL}";;
    "purple")	echo -e "${P}${@}${NORMAL}";;
    "cyan")	echo -e "${C}${@}${NORMAL}";;
    "white")	echo -e "${W}${@}${NORMAL}";;
    "BLACK")	echo -e "${EMK}${@}${NORMAL}";;
    "RED")	echo -e "${EMR}${@}${NORMAL}";;
    "GREEN")	echo -e "${EMG}${@}${NORMAL}";;
    "YELLOW")	echo -e "${EMY}${@}${NORMAL}";;
    "BLUE")	echo -e "${EMB}${@}${NORMAL}";;
    "PURPLE")	echo -e "${EMP}${@}${NORMAL}";;
    "CYAN")	echo -e "${EMC}${@}${NORMAL}";;
    "WHITE")	echo -e "${EMW}${@}${NORMAL}";;
    *)          echo "${@}";;
  esac
}

