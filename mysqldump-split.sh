#!/bin/bash
 
# Author: Andrew Howard

function output() {
  echo "OUTPUT ($(date +"%F %T")) ${@}"
}
function debug() {
  echo "DEBUG ($(date +"%F %T")) ${@}" >&2
}
function error() {
  echo "ERROR ($(date +"%F %T")) ${@}" >&2
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
  error "Unable to identify how to extract this file." >&2
  error "Please give me ASCII - optionally gzip'd, tar'd, or tar'd then gzip'd." >&2
  error "Note: We can't handle gzip-then-tar.  Also, that's weird."
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
  awk '/-- (Current Database:|Dumping (data|events|routines) for (table|database)|(Temporary t|T)able structure|Final view structure for view)/{n++}
    {print >"'${SRC}'.parts/out"n".txt"}
    END {print n}'
)
debug "Input file split into $((numParts+1)) segments"


# Pre-process the header
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
debug "Renaming first segment to 000-header.sql"
mv out.txt 000-header.sql


# Pre-process the footer
debug "Scraping footer constants from out${numParts}.txt into 000-footer.sql"
sed -n '/SET TIME_ZONE=@OLD_TIME_ZONE/,//p' "out${numParts}.txt" > 000-footer.sql
head -n -$( wc -l <000-footer.sql ) "out${numParts}.txt" > tmp
mv tmp "out${numParts}.txt"


DB="."
for x in $(seq 1 ${numParts} ); do
  COMMENT=$( head -n 1 "out${x}.txt" )
  debug "Processing out${x}.txt with content: ${COMMENT}"

  # Branch 1:
  # DB-contextual content
  # If dump was created with "--databases, -B" or if dump contains
  #  multiple DBs, there will be USE statements.  That's the only
  #  reliable source of DB-name, so without it, we just initialize
  #  $DB to ".", since we use $DB as a directory path.  In that case
  #  though, "-- Current Databse" never occurs in the dump, and this
  #  branch is skipped entirely.
  if grep -q '^-- Current Database:' <<<"${COMMENT}"; then
    # Note: "USE $DB" often occurs twice in a dump:
    #  1st: Create the DB, its tables, and populate table data
    #  2nd: Use the DB, create routines/events/views (& triggers, kinda)
    #       Must be second-pass, because creation of these metadata
    #       requires tables to already exist.

    # Remember which DB we're currently operating upon.
    DB=$( cut -d'`' -f2 <<<"${COMMENT}" )
    # Prep metadata dumpfiles with USE statements
    echo 'USE `'"${DB}"'`;' > "${DB}".events.sql
    echo 'USE `'"${DB}"'`;' > "${DB}".routines.sql
    echo 'USE `'"${DB}"'`;' > "${DB}".views.sql
    echo 'USE `'"${DB}"'`;' > "${DB}".triggers.sql

    if [[ ! -d "${DB}" ]]; then
      # First occurrence - we must be creating the DB.
      mkdir "${DB}"
      mv "out${x}.txt" "${DB}.create.sql"
    else
      # Subsequent occurrence - must be routine/event/view/trigger.
      # Each of those structures will have its own header, and will be caught
      #  by other conditionals, so there's no obvious important syntax here.
      # This file probably contains only a USE statement.
      cat "out${x}.txt" >> "${DB}.excess.sql"
      rm -f "out${x}.txt"
    fi

  # Branch Group 2:
  # Table schema & data
  # DB might be ".", but that's okay.
  elif grep -q '^-- Table structure' <<<"${COMMENT}" ||
       grep -q '^-- Temporary table structure for view' <<<"${COMMENT}"; then
    TBL=$( cut -d'`' -f2 <<<"${COMMENT}" )
    mv "out${x}.txt" "${DB}"/"${TBL}.schema.sql"
  elif grep -q '^-- Dumping data for table' <<<"${COMMENT}"; then
    TBL=$( cut -d'`' -f2 <<<"${COMMENT}" )
    mv "out${x}.txt" "${DB}"/"${TBL}.data.sql"

  # Branch Group 3:
  # Database-level entities (trigger/event/view/routine)
  # $DB might be ".", and that'd be a problem
  elif grep -q '^-- Dumping events' <<<"${COMMENT}"; then
    [[ "${DB}" == "." ]] && 
      cat "out${x}.txt" >> ./DB.events.sql ||
      cat "out${x}.txt" >> "${DB}".events.sql
    rm -f "out${x}.txt"
  elif grep -q '^-- Dumping routines' <<<"${COMMENT}"; then
    [[ "${DB}" == "." ]] && 
      cat "out${x}.txt" >> ./DB.routines.sql ||
      cat "out${x}.txt" >> "${DB}".routines.sql
    rm -f "out${x}.txt"
  elif grep -q '^-- Final view structure for view' <<<"${COMMENT}"; then
    [[ "${DB}" == "." ]] && 
      cat "out${x}.txt" >> ./DB.views.sql ||
      cat "out${x}.txt" >> "${DB}".views.sql
    rm -f "out${x}.txt"

  # Branch Group 4:
  # Catch-all
  else
    mv "out${x}.txt" "${DB}"/
  fi
done


