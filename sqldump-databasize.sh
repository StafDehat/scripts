#!/bin/bash
 
mkdir $1.databases
awk '/-- Current Database: /{n++} {print >"'$1'.databases/out"n".txt"}' $1
cd $1.databases
mv out.txt header.txt
for x in out*.txt; do
  DATABASE=$(head -1 $x | cut -d'`' -f2)
  mv $x $DATABASE.sql
done
