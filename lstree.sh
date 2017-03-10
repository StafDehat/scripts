#!/bin/bash

# Author: Andrew Howard

function dirlist() {
  [[ "$1" == "/" ]] && echo "/" ||
    echo "$( dirlist $( dirname "$1" ) ) $1"
}
ls -ld $( dirlist "$1" )

