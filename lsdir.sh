#!/bin/bash

# Author: Andrew Howard

function lsdir() {
  DIR="$1"
  if [ "$DIR" == "/" ]; then
    ls -ld "$DIR"
    return
  fi
  ls -ld "$DIR"
  lsdir $( dirname "$DIR" )
}

lsdir "$1" | column -t | sort -k 9

