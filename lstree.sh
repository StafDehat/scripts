#!/bin/bash

# Author: Andrew Howard

function dirlist() {
  if ! grep -qP '^\s*/' <<<"$1"; then
    echo "Absolute paths only, please"
    exit 1
  elif [ "$1" == "/" ]; then
    echo -n "/"
  else
    echo -n "$( dirlist $( dirname "$1" ) ) $1"
  fi
}

ls -ld $( dirlist "$1" )

