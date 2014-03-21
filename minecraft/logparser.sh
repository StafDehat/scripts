#!/bin/bash

# Author: Andrew Howard

DATE=`date +"%F-%T"`
LIVELOG=/home/minecraft/server.log
SERVERLOG=/home/minecraft/logs/server.log.$DATE
BACKUPDIR=/home/minecraft/statsdump
DATABASE=minecraft
DBUSER=minecraft
DBPASS="..."
MYSQL="mysql -u$DBUSER -p$DBPASS --skip-column-names $DATABASE"


# Rename the log to something timestamped
mv $LIVELOG $SERVERLOG
# Restart minecraft server
/etc/init.d/minecraft restart
# Take a mysqldump of the minecraft database
mysqldump -u$DBUSER -p$DBPASS $DATABASE > $BACKUPDIR/minecraft.sql.$DATE

# Delete old logs and dumps
tmpwatch --mtime 30d `dirname $SERVERLOG`
tmpwatch --mtime 30d $BACKUPDIR

# Clean some of the crap out of the server log
sed -i '/ \[INFO\] There are .* players online:\s*$/d' $SERVERLOG
sed -i '/ \[INFO\]\s*$/d' $SERVERLOG
sed -i '/ \[INFO\] Set the time to [0-9]*\s*$/d' $SERVERLOG

cat $SERVERLOG | while read LINE; do
  if [[ `echo $LINE | grep "\[INFO\]" | grep -c " joined the game$"` -gt 0 ||
        `echo $LINE | grep "\[INFO\]" | grep -c " logged in with entity id "` -gt 0 ]]; then
    TIMESTAMP=`echo $LINE | cut -d\  -f1-2`
    LOGIN=`date -d "$TIMESTAMP" +"%s"`
    PLAYER=`echo $LINE | sed 's/.*\[INFO\] \(.*\)\[.*\?/\1/'`
    # Determine whether PLAYER exists in table yet or not
    if [ `$MYSQL -e "SELECT count(id) FROM players WHERE name = '$PLAYER';"` -eq 0 ]; then
      # If not exists, create entry for PLAYER
      $MYSQL -e "INSERT INTO players (name) VALUES('$PLAYER');"
      echo "Added $PLAYER to 'players' table"
    fi
    PLAYERID=`$MYSQL -e "SELECT id FROM players WHERE name = '$PLAYER' LIMIT 1;"`
    $MYSQL -e "INSERT INTO sessions (playerid, login) VALUES('$PLAYERID', '$TIMESTAMP');"
    echo "Recorded login for $PLAYER ($PLAYERID) at $TIMESTAMP"
  elif [[ `echo $LINE | grep "\[INFO\]" | grep -c "lost connection:"` -gt 0 ||
          `echo $LINE | grep "\[INFO\]" | grep -c " left the game$"` -gt 0 ]]; then
    TIMESTAMP=`echo $LINE | cut -d\  -f1-2`
    LOGOUT=`date -d "$TIMESTAMP" +"%s"`
    PLAYER=`echo $LINE | cut -d\  -f4`
    PLAYERID=`$MYSQL -e "SELECT id FROM players WHERE name = '$PLAYER' LIMIT 1;"`
    # Find session corresponding to this logout, update the logout field.
    SESSIONID=`$MYSQL -e "SELECT MAX(id) FROM sessions WHERE playerid = '$PLAYERID' AND logout IS NULL;"`
    $MYSQL -e "UPDATE sessions SET logout = '$TIMESTAMP' WHERE id = '$SESSIONID' LIMIT 1;"
    echo "Set logout time for session id $SESSIONID"
  elif [[ `echo $LINE | grep -c "\[INFO\] Stopping the server"` -gt 0 ||
          `echo $LINE | grep -c "\[INFO\] Starting minecraft server"` -gt 0 ]]; then
    TIMESTAMP=`echo $LINE | cut -d\  -f1-2`
    # Update logout time for any players that were logged in during a server stop.
    #   or... update logout time for any players that must have been logged in during a crash, and we're
    #   detecting that crash by a subsequent startup while there are "active" sessions.
    $MYSQL -e "UPDATE sessions SET logout = '$TIMESTAMP', dirty = '1' WHERE logout IS NULL;"
    echo "Set logout time for all NULL logouts to $TIMESTAMP"
  fi
done

PLAYERLIST=`$MYSQL -e "SELECT name FROM players;"`

# Count deaths
for PLAYER in $PLAYERLIST; do
  grep -v "lost connection" $SERVERLOG \
  | grep -v " joined the game$" \
  | grep -v " left the game$" \
  | awk '$4 ~ /^'$PLAYER'$/ && $3 ~ /^\[INFO\]$/ {for (i = 1; i <= NF; i++) printf $i " "; print ""}' \
  | while read LINE; do
    TIMESTAMP=`echo $LINE | cut -d\  -f1-2`
    DEATH=`echo $LINE | cut -d\  -f5-`
    if [ `$MYSQL -e "SELECT COUNT(id) FROM deathsources WHERE description = '$DEATH';"` -eq 0 ]; then
      $MYSQL -e "INSERT INTO deathsources (description) VALUES('$DEATH');"
      echo "Added source of death: $DEATH"
    fi
    DEATHID=`$MYSQL -e "SELECT id FROM deathsources WHERE description = '$DEATH';"`
    PLAYERID=`$MYSQL -e "SELECT id FROM players WHERE name = '$PLAYER';"`
    $MYSQL -e "INSERT INTO playerdeaths (playerid, deathid, time) VALUES('$PLAYERID', '$DEATHID', '$TIMESTAMP');"
    echo "Recorded death \"$DEATH\" for $PLAYER"
  done
done

gzip $SERVERLOG

