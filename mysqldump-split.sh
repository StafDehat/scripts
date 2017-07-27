#!/bin/bash
 
# Author: Andrew Howard

function usage() {
  cat <<EOF
Usage:
  $0 /path/to/dumpfile

Examples:
  $0 /backup/all-dbs.sql
  $0 /backup/all-dbs.sql.gz
  $0 /backup/all-dbs.sql.tar
  $0 /backup/all-dbs.sql.tgz

Supported file formats:
  ASCII text
  ASCII text (gzip compressed data)
  POSIX tar archive (GNU) containing ASCII text
  POSIX tar archive (GNU) containing ASCII text (gzip compressed data)

Description:
  Script will create a directory at "/path/to/dumpfile.parts", containing
    all the constituent pieces of your original dump.
  To reconstitute, just cat the desired pieces together like so:
  # cat /path/to/dumpfile.parts/000-header.sql \
  #     /path/to/dumpfile.parts/myFirstDatabase.sql \
  #     /path/to/dumpfile.parts/myFirstDatabase/myFirstTable.schema.sql \
  #     /path/to/dumpfile.parts/myFirstDatabase/myFirstTable.data.sql \
  #     /path/to/dumpfile.parts/myFirstDatabase/mySecondTable.schema.sql \
  #     /path/to/dumpfile.parts/myFirstDatabase/mySecondTable.data.sql \
  #     /path/to/dumpfile.parts/mySecondDatabase.sql \
  #     /path/to/dumpfile.parts/mySecondDatabase/*.schema.sql \
  #     /path/to/dumpfile.parts/mySecondDatabase/*.data.sql \
  #     /path/to/dumpfile.parts/000-footer.sql \
  #   > /backup/my-new-dumpfile.sql

  Note: The order of files in the 'cat' command matters.  Rules are:
    1) cat 000-header.sql first
    2) For any given database, cat DBName.sql immediately prior to
       all of that DB's tables.  (Because this file creates the DB,
       and sets that DB to the default)
    3) For any given table, cat the .schema.sql file before the
       corresponding .data.sql file.
    4) Finish one database *completely* before you move on to the
       next!
    5) cat 000-footer.sql.last
EOF
}

SRC="${1}"

if [[ "${SRC}" == "-h" ]] ||
   [[ "${SRC}" == "--help" ]]; then
  usage && exit 0
fi

if grep -q 'gzip\|compressed' <(file "${SRC}"); then
  catcmd='zcat'
  if grep -q 'tar archive' <(file -z "${SRC}"); then
    catcmd='tar --to-stdout -xzf'
  else
    echo "Error: Unable to identify how to extract this file." >&2
    echo "Please give me ASCII - optionally gzip'd, tar'd, or tar-gz'd." >&2
    exit 1
  fi
elif grep -qP 'ASCII' <(file "${SRC}"); then
  catcmd='cat'
elif grep -q 'tar archive' <(file -z "${SRC}"); then
  catcmd='tar --to-stdout -xf'
else
  echo "Error: Unable to identify how to extract this file." >&2
  echo "Please give me ASCII - optionally gzip'd, tar'd, or tar-gz'd." >&2
  exit 1
fi

mkdir ${SRC}.parts
numParts=$(
  ${catcmd} "${SRC}" |
  awk '/-- (Current Database:|Dumping [^\s]+ for|Table structure)/{n++}
    {print >"'${SRC}'.parts/out"n".txt"}
    END {print n}'
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

