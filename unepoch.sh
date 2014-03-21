#!/bin/bash

# Author: Andrew Howard

while read LINE; do
  echo $LINE | perl -pe 's/(\d+)/localtime($1)/e'
done

# It's way better to just do this:
# alias unepoch="perl -pe 's/(\d+)/localtime($1)/e'"

