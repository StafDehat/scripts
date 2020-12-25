#!/bin/bash

function debug() {
  local ts=$( date +"%F %T.%N" )
  echo "${ts}: ${@}" >&2
}

