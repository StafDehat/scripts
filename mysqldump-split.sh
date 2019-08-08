#!/bin/bash
 
# Author: Andrew Howard

function debug() {
  echo "${@}" >&2
}

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
  Unicode text
  Unicode text (gzip compressed data)
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

function isText() {
  grep -qP '(ASCII|Unicode) text' <<<"${@}"
  return $?
}
function isZip() {
  grep -q 'gzip\|compressed' <<<"${@}"
  return $?
}
function isTar() {
  grep -q 'tar archive' <<<"${@}"
  return $?
}
function errUnknownInput() {
  echo "Error: Unable to identify how to extract this file." >&2
  echo "Please give me ASCII - optionally gzip'd, tar'd, or tar'd then gzip'd." >&2
  echo "Note: We can't handle gzip-then-tar.  Also, that's weird."
}


SRC="${1}"

if [[ "${SRC}" == "-h" ]] ||
   [[ "${SRC}" == "--help" ]]; then
  usage && exit 0
fi

#
# Try to identify the input file format:
if isZip $(file "${SRC}"); then
  # Check what's inside the compression
  if isTar $(file -z "${SRC}"); then
    catcmd='tar --to-stdout -xzf'
  elif isText $(file -z "${SRC}"); then
    catcmd='zcat'
  else
    errUnknownInput; exit 1
  fi
else
  # Well it's not compressed
  if isText $(file "${SRC}"); then
    catcmd='cat'
  elif isTar $(file "${SRC}"); then
    debug "WARNING: Input format is TAR, but we can't test past that."
    debug " Continuing on the *assumption* that it's a tar'd text file."
    catcmd='tar --to-stdout -xf'
  else
    errUnknownInput; exit 1
  fi
fi

if [[ -d "${SRC}.parts" ]]; then
  cat <<EOF
ERROR: Directory "${SRC}.parts" already exists.
Aborting script with no changes, to avoid clobbering something important.
EOF
  exit 1
fi
mkdir ${SRC}.parts
numParts=$(
  ${catcmd} "${SRC}" |
  awk '/-- (Current Database:|Dumping [^\s]+ for|Table structure)/{n++}
    {print >"'${SRC}'.parts/out"n".txt"}
    END {print n}'
)

cd "${1}.parts"
if ! isText $(file out.txt); then
  mv out.txt awk-result
  cat <<EOF
Whatever just came out of $(basename "${SRC}"), it wasn't text.
Instead, we found:
  $(file awk-result)
As such, script aborts here.
EOF
  exit 1
fi
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
    if [[ ! -d "${DB}" ]]; then
      # First occurrence - we must be creating the DB.
      mkdir "${DB}"
      mv "out${x}.txt" "${DB}.create.sql"
    else
      # Subsequent occurrence - must be triggers/views/etc that require tables to have
      #   already been created.
      cat "out${x}.txt" >> "${DB}.post-tables.sql"
      rm -f "out${x}.txt"
    fi
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

