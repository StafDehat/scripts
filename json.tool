#!/bin/bash

# Author: Andrew Howard
# Purpose: Convert JSON into a SNMP MIB-like output, for easy grepping

EXITLEVELS=0


#
# Verify the existence of pre-req's
PREREQS="grep sed tr echo"
PREREQFLAG=0
for PREREQ in $PREREQS; do
  which $PREREQ &>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Gotta have '$PREREQ' binary to run."
    PREREQFLAG=1
  fi
done
if [ $PREREQFLAG -ne 0 ]; then
  exit 1
fi


#
# Define a usage statement
function usage() {
  echo "Usage: $0 [-h]\\"
  echo "         [-F Field-Separator] \\"
  echo "         [-p Prefix]"
  echo
  echo "Arguments:"
  echo "  -F X	Use 'X' to separate fields."
  echo "  -h	Print this help."
  echo "  -p X	Prefix each line with the field 'X'."
}


#
# Handle command-line args
PREFIX=""
DELIMITER='/'
USAGEFLAG=0
while getopts ":F:hp:" arg; do
  case $arg in
    F) DELIMITER="$OPTARG";;
    h) usage && exit 0;;
    p) PREFIX="$OPTARG";;
    :) echo "ERROR: Option -$OPTARG requires an argument."
       USAGEFLAG=1;;
    *) echo "ERROR: Invalid option: -$OPTARG"
       USAGEFLAG=1;;
  esac
done #End arguments
shift $(($OPTIND - 1))
if [ "$USAGEFLAG" -ne 0 ]; then
  usage && exit 1
fi



# Handle a single item from this list/array
function dolineitem() {
  local PREFIX=$1
  while read LINE; do
    LINE=$( echo "$LINE" | tr -d '"' )
    case $LINE in
      '{' ) # Start a list
        docurlygroup $PREFIX;;
      '[' ) # Start an array
        dosquaregroup $PREFIX;;
      ',' ) #Line Terminator
        echo "$PREFIX"
        return;;
      '}'|']' ) # Line terminators that also terminate a group
        EXITLEVELS=1
        echo "$PREFIX"
        return;;
      * ) #Values & Assignment
        PREFIX="${PREFIX}${DELIMITER}${LINE}";;
    esac
  done
}


# Handle whatever's inside the { } brackets
function docurlygroup() {
  local PREFIX=$1
  while true; do
    dolineitem "$PREFIX"
    if [ "$EXITLEVELS" -ne 0 ]; then
      EXITLEVELS=0
      return
    fi
  done
}


# Handle whatever's inside the [ ] brackets
function dosquaregroup() {
  local PREFIX=$1
  local COUNT=0
  while true; do
    dolineitem "${PREFIX}${DELIMITER}${COUNT}"
    COUNT=$(( $COUNT + 1 ))
    if [ "$EXITLEVELS" -ne 0 ]; then
      EXITLEVELS=$(( $EXITLEVELS - 1 ))
      return
    fi
  done
}


while read LINE; do
  if [ $( echo "$PREFIX" | grep -c "$LINE" ) -eq 0 ]; then
    echo "$LINE"
  fi
  PREFIX="$LINE"
done < <(
  dolineitem $PREFIX < <(
  ESCAPED=0
  INQUOTE=0
  LINE=""
  cat | 
    sed 's/\\/\\\\/g' | #This sed is required because "read" strips escape characters
    while read -n 1 CHAR; do
      if [ "$ESCAPED" -eq 1 ]; then
        LINE="$LINE\\$CHAR"
        ESCAPED=0
      elif [ "$INQUOTE" -eq 1 ]; then
        case "$CHAR" in
          ("\\")
            ESCAPED=1
          ;;
          ('"')
            LINE="$LINE$CHAR"
            INQUOTE=0
          ;;
          (*)
            LINE="$LINE$CHAR"
          ;;
        esac
      else #INQUOTE=0
        case "$CHAR" in
          ("\\")
            ESCAPED=1
          ;;
          ('"')
            INQUOTE=1
            LINE="$LINE$CHAR"
          ;;
          ('{'|'}'|'['|']'|',')
            echo "$LINE"
            LINE=""
            echo "$CHAR"
          ;;
          (':')
            echo "$LINE"
            LINE=""
          ;;
          (*)
            LINE="$LINE$CHAR"
          ;;
        esac
      fi
    done | grep -vE '^\s*$'
  )
)

