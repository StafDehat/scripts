#!/bin/bash

mkdir $1.tables
awk '/-- Table structure for table/{n++} {print >"'$1'.tables/out"n".txt"}' $1
cd $1.tables
for x in *; do
  TABLE=$(head -1 $x | cut -d'`' -f2)
  mv $x $TABLE.sql
done
