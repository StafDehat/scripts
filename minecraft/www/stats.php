<?php
require_once("./db-settings.php");
require_once("./includes.php");
date_default_timezone_set('UTC');
?>

<html>
<head>
  <title></title>
  <script src="sorttable.js"></script>
  <style>
/* Sortable tables */
table.sortable thead {
    background-color:#555;
    color:#ddd;
    font-weight: bold;
    cursor: default;
}
table.sortable tbody tr td{
  border-bottom:thin solid black;
}
/*
table.sortable tbody tr:nth-child(2n) td {
  background: #ffcccc;
}
table.sortable tbody tr:nth-child(2n+1) td {
  background: #ccfffff;
}
*/
  </style>
</head>

<body>
<table border="0" class="sortable">
<tr>
  <th>Account</th>
  <th>IRL</th>
  <th>Deaths</th>
  <th>Time Played</th>
  <th>Average Lifespan</th>
  <th>Longest Life</th>
  <th>Shortest Life</th>
</tr>
<?php
# Player deaths
$query  = "
SELECT id,
       name,
       realname,
       deaths,
       SEC_TO_TIME(playtime) as playtime,
       SEC_TO_TIME(playtime / (deaths+1)) as avglife
FROM (SELECT p.id,
             p.name,
             p.realname,
             SUM(TIME_TO_SEC(TIMEDIFF(s.logout, s.login))) as playtime,
             (SELECT COUNT(*) FROM playerdeaths d WHERE d.playerid = p.id) as deaths
      FROM players p 
      INNER JOIN sessions s ON s.playerid = p.id
      GROUP BY p.id) as lives
ORDER BY avglife DESC;";
$result = mysql_query($query) or die(mysql_error());
while ($row = mysql_fetch_assoc($result)) {
  echo "<tr>\n";
  echo "<td>". $row["name"] ."</td>\n";
  echo "<td>". $row["realname"] ."</td>\n";
  echo "<td><a href='playerstats.php?pid=". $row["id"] ."'>". $row["deaths"] ."</a></td>\n";
  echo "<td sorttable_customkey='". time2secs($row["playtime"]) ."'>". $row["playtime"] ."</td>\n";
  echo "<td sorttable_customkey='". time2secs($row["avglife"])  ."'>". $row["avglife"]  ."</td>\n";

  # Calculate their longest lifespan
  $query = "SELECT login,logout FROM sessions WHERE playerid = '". $row["id"] ."' ORDER BY login;";
  $sessionSQL = mysql_query($query) or die(mysql_error());
  $query = "SELECT time FROM playerdeaths WHERE playerid = '". $row["id"] ."' ORDER BY time;";
  $deathSQL = mysql_query($query) or die(mysql_error());
  $lives = Array();

  $session = mysql_fetch_assoc($sessionSQL);
  $lifeStart = strtotime($session["login"]);
  $lifeLength = 0;

  while ($death = mysql_fetch_assoc($deathSQL)) {
    $timeofdeath = strtotime($death["time"]);
    # Loop over sessions
    do {
      $sessionstart = strtotime($session["login"]);
      $sessionstop = strtotime($session["logout"]);

      if ( $timeofdeath > $sessionstop ) { #Survived this session
        if ( $lifeStart > $sessionstart ) { #Started life this session
          $lifeLength = $lifeLength + ( $sessionstop - $lifeStart );
        } else { #Started life prior to this session
          $lifeLength = $lifeLength + ( $sessionstop - $sessionstart );
        }
#        $session = mysql_fetch_assoc($sessionSQL);
      } else { #Died this session
        if ( $lifeStart > $sessionstart ) { #Started life this session
          $lifeLength = $lifeLength + ( $timeofdeath - $lifeStart );
        } else { #Started life prior to this session
          $lifeLength = $lifeLength + ( $timeofdeath - $sessionstart );
        }
        $lifeStart = $timeofdeath;
        $lives[] = $lifeLength;
        $lifeLength = 0;
        break;
      }
    } while ( $session = mysql_fetch_assoc($sessionSQL) );
  }
  $sessionstart = strtotime($session["login"]);
  $sessionstop = strtotime($session["logout"]);
  if ( $lifeStart > $sessionstart ) {
    $lifeLength = $lifeLength + ( $sessionstop - $lifeStart );
  } else {
    $lifeLength = $lifeLength + ( $sessionstop - $sessionstart );
  }

  $lives[] = $lifeLength;
  $maxlife = max($lives);
  echo "<td sorttable_customkey='$maxlife'>". gmdate("H:i:s",$maxlife) ."</td>\n";
  $minlife = min($lives);
  echo "<td sorttable_customkey='$minlife'>". gmdate("H:i:s",$minlife) ."</td>\n";
  echo "</tr>\n";
}
?>
</table>


<table border="0" class="sortable">
<tr><th>Kills</th><th>Source</th></tr>
<?php
# Death source counts
$query = "
SELECT deathsources.id,
       COUNT(*) as kills,
       description
  FROM deathsources
LEFT JOIN playerdeaths ON deathsources.id = playerdeaths.deathid
 WHERE description != ''
GROUP BY description ORDER BY kills DESC;";
$result = mysql_query($query) or die(mysql_error());
while ($row = mysql_fetch_assoc($result)) {
  echo "<tr>";
  echo "<td><a href='deathstats.php?did=". $row["id"] ."'>". $row["kills"] ."</a></td>\n";
  echo "<td>". $row["description"] ."</td>\n";
  echo "</tr>\n";
}
?>
</table>

</body>
</html>
