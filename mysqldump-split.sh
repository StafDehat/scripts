#!/bin/bash
 
# Author: Andrew Howard

SRC="${1}"

mkdir ${SRC}.parts
numParts=$(
  awk '/-- (Current Database:|Dumping [^\s]+ for|Table structure)/{n++}
    {print >"'${SRC}'.parts/out"n".txt"}
    END {print n}' ${SRC}
)

cd $1.parts
mv out.txt 000-header.sql

# Pre-process the file containing the footer.
sed -n '/SET TIME_ZONE=@OLD_TIME_ZONE/,//p' "out${numParts}.txt" > 000-footer.sql
head -n -$( wc -l <000-footer.sql ) "out${numParts}.txt" > tmp
mv tmp "out${numParts}.txt"

DB="."
for x in $(seq 1 ${numParts} ); do
  COMMENT=$( head -n 1 "out${x}.txt" )
  if grep -q '^-- Current Database:' <<<"${COMMENT}"; then
    DB=$( cut -d'`' -f2 <<<"${COMMENT}" )
    mkdir "${DB}"
    mv "out${x}.txt" "${DB}.sql"
  elif grep -q '^-- Table structure' <<<"${COMMENT}"; then
    TBL=$( cut -d'`' -f2 <<<"${COMMENT}" )
    mv "out${x}.txt" "${DB}"/"${TBL}.schema.sql"
  elif grep -q '^-- Dumping data for table' <<<"${COMMENT}"; then
    TBL=$( cut -d'`' -f2 <<<"${COMMENT}" )
    mv "out${x}.txt" "${DB}"/"${TBL}.data.sql"
  elif grep -q '^-- Dumping events' <<<"${COMMENT}"; then
    mv "out${x}.txt" "${DB}"/events.sql
  elif grep -q '^-- Dumping routines' <<<"${COMMENT}"; then
    mv "out${x}.txt" "${DB}"/routines.sql
  else
    mv "out${x}.txt" "${DB}"/
  fi
done

