<?php

// Author: Andrew Howard

require_once("./db-settings.php");
require_once("./includes.php");

$query = "SELECT name FROM players WHERE id = '". mysql_real_escape_string($_GET['pid']) ."';";
$result = mysql_query($query) or die(mysql_error());
$row = mysql_fetch_assoc($result);
$player = $row["name"];
?>

<html>
<head>
  <title>Death details for player <?php echo $player; ?></title>
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
<table border="0" class="sortable">
<tr>
  <th>Time</th>
  <th>Source</th>
</tr>
<?php
# Player deaths
$query  = "
SELECT playerdeaths.time, 
       deathsources.description 
  FROM playerdeaths LEFT JOIN deathsources ON playerdeaths.deathid = deathsources.id 
 WHERE playerdeaths.playerid = '". mysql_real_escape_string($_GET['pid']) ."' 
 ORDER BY playerdeaths.time;";
$result = mysql_query($query) or die(mysql_error());

while ($row = mysql_fetch_assoc($result)) {
  echo "<tr>";
  echo "<td sorttable_customkey='". time2secs($row["time"]) ."'>". $row["time"] ."</td>\n";
  echo "<td>". $row["description"] ."</td>\n";
  echo "</tr>\n";
}
?>
</table>

</body>
</html>
