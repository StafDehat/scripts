#!/bin/bash

# Author: Andrew Howard

function dirlist() {
  if [ -z "$1" ]; then
    return
  elif [ "$1" == "/" ]; then
    echo -n "/"
  else
    echo -n "$( dirlist $( dirname "$1" ) ) $1"
  fi
}

ls -ld $( dirlist "$1" )

