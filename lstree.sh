#!/bin/bash

# Author: Andrew Howard

function dirlist() {
  if [ "$1" == "/" ]; then
    echo -n "/"
  else
    echo -n "$( dirlist $( dirname "$1" ) ) $1"
  fi
}


if ! grep -qP '^\s*/' <<<"$1"; then
  echo "Absolute paths only, please"
  exit 1
fi
ls -ld $( dirlist "$1" )

