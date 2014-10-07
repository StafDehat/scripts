<?php

// Author: Andrew Howard

require_once("./db-settings.php");
require_once("./includes.php");
?>

<html>
<head>
  <title>Occurrences</title>
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
  </style>
</head>


<body>
Deaths where the player 
<?php
$query = "SELECT description FROM deathsources WHERE id = '". mysql_real_escape_string($_GET['did']) ."';";
$result = mysql_query($query) or die(mysql_error());
$row = mysql_fetch_assoc($result);
echo $row["description"];
?>

<table border="0" class="sortable">
<tr>
  <th>Time</th>
  <th>The Unfortunate Soul</th>
</tr>
<?php
# Player deaths
$query  = "
SELECT playerdeaths.time, 
       players.name 
  FROM playerdeaths LEFT JOIN players ON playerdeaths.playerid = players.id 
 WHERE playerdeaths.deathid = '". mysql_real_escape_string($_GET['did']) ."' 
 ORDER BY playerdeaths.time;";
$result = mysql_query($query) or die(mysql_error());

while ($row = mysql_fetch_assoc($result)) {
  echo "<tr>";
  echo "<td sorttable_customkey='". time2secs($row["time"]) ."'>". $row["time"] ."</td>\n";
  echo "<td>". $row["name"] ."</td>\n";
  echo "</tr>\n";
}
?>
</table>

</body>
</html>
