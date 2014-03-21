#!/bin/bash

# Author: Andrew Howard

while true; do
  sleep $(( $RANDOM % 1200 ))
  service minecraft command /time set $(( $RANDOM % 24 ))000
done

