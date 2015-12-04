<?php
/************ Use this MySQL table structure ***********************
create table players (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  added datetime NOT NULL,
  voided   datetime,
  num1 TINYINT NOT NULL,
  num2 TINYINT NOT NULL,
  num3 TINYINT NOT NULL,
  num4 TINYINT NOT NULL,
  num5 TINYINT NOT NULL,
  name varchar(100) NOT NULL
);

create table winners (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  date datetime,
  num1 TINYINT,
  num2 TINYINT,
  num3 TINYINT,
  num4 TINYINT,
  num5 TINYINT
);
********************************************************************/

function connect() {
  $con = mysql_connect("localhost","USER","PASS") or die('Could not connect: ' . mysql_error());
  mysql_select_db("DATABASE", $con);
}

function isPaid($playerid, $winnerid) {
  $query = "SELECT * FROM paid WHERE playerid = '". $playerid ."' ";
  $query .= "and winnerid = '". $winnerid ."'";
  $result = mysql_query($query) or die(mysql_error());
  return mysql_num_rows($result);
}

function getWinners() {
  $query = "SELECT * from winners ORDER BY date";
  return mysql_query($query);
}

function getPlayers($validTime) {
  if ( $validTime > 0 ) {
    $query = "SELECT * FROM players WHERE added < '". $validTime ."' AND ";
    $query .= "( voided > '". $validTime ."' OR ";
    $query .= "  voided IS NULL )";
  } else {
    $query = "SELECT * FROM players";
  }
  $query .= " ORDER BY name, added";
  return mysql_query($query);
}

function addWinner() {
  extract($_POST);
  if ( $winNum1 > 0 && $winNum1 <= 25 &&
       $winNum2 > 0 && $winNum2 <= 25 &&
       $winNum3 > 0 && $winNum3 <= 25 &&
       $winNum4 > 0 && $winNum4 <= 25 &&
       $winNum5 > 0 && $winNum5 <= 25 &&
       $winNum1 != $winNum2 &&
       $winNum1 != $winNum3 &&
       $winNum1 != $winNum4 &&
       $winNum1 != $winNum5 &&
       $winNum2 != $winNum3 &&
       $winNum2 != $winNum4 &&
       $winNum2 != $winNum5 &&
       $winNum3 != $winNum4 &&
       $winNum3 != $winNum5 &&
       $winNum4 != $winNum5    ) {
    $query = "INSERT INTO winners(date, num1, num2, num3, num4, num5) ";
    $query .= "VALUES(";
    if ( !empty($date) && strtotime($date) ) {
      echo "Using manually-specified date.<br />\n";
      $query .= "'". $date ."',";
    } else {
      echo "Date not specified, or invalid - Current time and date used.<br />\n";
      $query .= "NOW(),";
    }
    $query .= "'". intval($winNum1) ."',";
    $query .= "'". intval($winNum2) ."',";
    $query .= "'". intval($winNum3) ."',";
    $query .= "'". intval($winNum4) ."',";
    $query .= "'". intval($winNum5) ."')";
    mysql_query($query) OR die("Unable to add numbers: ". mysql_error());
    echo "New winning numbers (".intval($winNum1)."-".intval($winNum2)."-".intval($winNum3)."-".intval($winNum4)."-".intval($winNum5).") added.<br />\n";
    echo "<a href=''>Click here to refresh the page.</a><br />\n";
  } else {
    echo "ERROR: Values must be numbers 1 to 25, and no duplicates are allowed.";
  }
}

function addPlayer() {
  extract($_POST);
  if ( $playerNum1 > 0 && $playerNum1 <= 25 &&
       $playerNum2 > 0 && $playerNum2 <= 25 &&
       $playerNum3 > 0 && $playerNum3 <= 25 &&
       $playerNum4 > 0 && $playerNum4 <= 25 &&
       $playerNum5 > 0 && $playerNum5 <= 25 &&
       $playerNum1 != $playerNum2 &&
       $playerNum1 != $playerNum3 &&
       $playerNum1 != $playerNum4 &&
       $playerNum1 != $playerNum5 &&
       $playerNum2 != $playerNum3 &&
       $playerNum2 != $playerNum4 &&
       $playerNum2 != $playerNum5 &&
       $playerNum3 != $playerNum4 &&
       $playerNum3 != $playerNum5 &&
       $playerNum4 != $playerNum5    ) {

    // Invalidate the player's old numbers
    $query = "UPDATE players SET voided = NOW() WHERE name = '". mysql_real_escape_string($playerName) ."'";
    mysql_query($query) or die(mysql_error());
    // Insert the player's new numbers
    $query = "INSERT INTO players(added, num1, num2, num3, num4, num5, name)
              VALUES(NOW(),
              '".intval($playerNum1)."',
              '".intval($playerNum2)."',
              '".intval($playerNum3)."',
              '".intval($playerNum4)."',
              '".intval($playerNum5)."',
              '".mysql_real_escape_string($playerName)."')";
    mysql_query($query) or die(mysql_error());
    echo "Player registered.<br />";
    echo "<a href=''>Click here to refresh the page.</a><br />\n";
  } else {
    echo "ERROR: Values must be numbers 1 to 25, and no duplicates are allowed.";
  }
}

function deleteWinner() {
  extract($_POST);
  $query = "DELETE FROM winners WHERE id = '". $winnerID ."'";
  mysql_query($query) or die(mysql_error());
  echo "Selected numbers deleted.<br />\n";
  echo "<a href=''>Click here to refresh the page.</a><br />\n";
}

function showMatches() {
  extract($_POST);
  $count=0;
  $query = "SELECT * FROM winners WHERE id = '". $winnerID ."' ORDER BY date";
  $winner = mysql_query($query) or die(mysql_error());
  $winner = mysql_fetch_array($winner);

  // Pull list of all valid numbers at time of drawing
  $players = getPlayers($winner['date']);

  echo "<form name='payOut' action='' method='post'>\n";
  echo "Selected numbers yielded the following winners<br />\n";
  echo "<table border=1>\n";
  echo "<tr>\n";
  echo "<th>Added</th>\n";
  echo "<th>Voided</th>\n";
  echo "<th>#1</th>\n";
  echo "<th>#2</th>\n";
  echo "<th>#3</th>\n";
  echo "<th>#4</th>\n";
  echo "<th>#5</th>\n";
  echo "<th>Player</th>\n";
  echo "<th>Type of win</th>\n";
  echo "<th>Paid</th>\n";
  echo "<th>Mark paid</th>\n";
  echo "</tr>\n";

  while ( $player=mysql_fetch_array($players) ) {
    // Add up the matches
    $straightMatch = 0;
    $boxMatch = 0;
    if ( $winner['num1'] == $player['num1'] ) {
      $straightMatch++;
      $boxMatch++;
    }
    else if ( $winner['num1'] == $player['num2'] ||
              $winner['num1'] == $player['num3'] ||
              $winner['num1'] == $player['num4'] ||
              $winner['num1'] == $player['num5'] ) {
      $boxMatch++;
    }
    if ($winner['num2'] == $player['num2']) {
      $straightMatch++;
      $boxMatch++;
    }
    else if ( $winner['num2'] == $player['num1'] ||
              $winner['num2'] == $player['num3'] ||
              $winner['num2'] == $player['num4'] ||
              $winner['num2'] == $player['num5'] ) {
      $boxMatch++;
    }
    if ($winner['num3'] == $player['num3']) {
      $straightMatch++;
      $boxMatch++;
    }
    else if ( $winner['num3'] == $player['num1'] ||
              $winner['num3'] == $player['num2'] ||
              $winner['num3'] == $player['num4'] ||
              $winner['num3'] == $player['num5'] ) {
      $boxMatch++;
    }
    if ($winner['num4'] == $player['num4']) {
      $straightMatch++;
      $boxMatch++;
    }
    else if ( $winner['num4'] == $player['num1'] ||
              $winner['num4'] == $player['num2'] ||
              $winner['num4'] == $player['num3'] ||
              $winner['num4'] == $player['num5'] ) {
      $boxMatch++;
    }
    if ($winner['num5'] == $player['num5']) {
      $straightMatch++;
      $boxMatch++;
    }
    else if ( $winner['num5'] == $player['num1'] ||
              $winner['num5'] == $player['num2'] ||
              $winner['num5'] == $player['num3'] ||
              $winner['num5'] == $player['num4'] ) {
      $boxMatch++;
    }

    // Print player info, if a winner
    if ( $straightMatch >= 3 ||
         $boxMatch      >= 3    ) {
      echo "<tr>\n";
      echo "<td>" . $player['added'] . "</td>\n";
      echo "<td>" . $player['voided'] . "</td>\n";
      echo "<td>" . $player['num1'] . "</td>\n";
      echo "<td>" . $player['num2'] . "</td>\n";
      echo "<td>" . $player['num3'] . "</td>\n";
      echo "<td>" . $player['num4'] . "</td>\n";
      echo "<td>" . $player['num5'] . "</td>\n";
      echo "<td>" . $player['name'] . "</td>\n";
      // Determine the type of win
      if ( $straightMatch == 5 ) {
        echo "<td>Straight 5</td>";
      } else if ( $straightMatch == 4 ) {
        echo "<td>Straight 4</td>";
      } else if ( $boxMatch == 5 ) {
        echo "<td>Boxed 5</td>";
      } else if ( $straightMatch == 3 ) {
        echo "<td>Straight 3</td>";
      } else if ( $boxMatch == 4 ) {
        echo "<td>Boxed 4</td>";
      } else if ( $boxMatch == 3 ) {
        echo "<td>Boxed 3</td>";
      } else {
        echo "<td>Unknown</td>";
      }
      // Determine and report if win has already been paid
      if ( isPaid($player['id'], $winner['id']) ) {
        echo "<td align='center'>X</td>\n";
      } else {
        echo "<td></td>\n";
      }
      // Checkboxes for marking wins as paid
      echo "<td align='center'><input type='checkbox' name='checkbox". $player['id'] .":". $winner['id'] ."' /></td>\n";
      echo "</tr>\n";
      $count++;
    }
  }
  echo "</table>\n";
  echo "<input type='submit' name='pay' value='Mark as paid' />\n";
  echo "</form>\n";

  echo "Total winners: ". $count ."<br />\n";
  echo "<a href=''>Click here to refresh the page.</a><br />\n";
}

function markPaidPlayers() {
  $keys = array_keys($_POST);
  foreach($keys as $key) {
    if ( $_POST[$key] == "on" &&
         strpos($key, "checkbox") === 0 ) {
      preg_match('/^checkbox(\d+):(\d+)$/', $key, $ids);
      if ( ! isPaid($ids[1], $ids[2]) ) {
        $query = "INSERT INTO paid(playerid, winnerid) values('". $ids[1] ."', '". $ids[2] ."')";
        mysql_query($query) or die(mysql_error());
      }
    }
  }
  echo "The checked players have been marked as paid.<br />\n";
  echo "<a href=''>Click here to refresh the page.</a><br />\n";
}

function deletePlayer() {
  extract($_POST);
  $query = "DELETE FROM players WHERE id = '". $playerID ."'";
  mysql_query($query) or die(mysql_error());
  echo "<a href=''>Click here to refresh the page.</a><br />\n";
}

function checkIfWinner() {
  extract($_POST);
  $query = "SELECT * FROM players WHERE id = '". $playerID ."' ORDER BY name, added";
  $player = mysql_query($query) or die(mysql_error());
  $player = mysql_fetch_array($player);

  // Pull list of all winning numbers
  $winners = getWinners();

  echo "Selected numbers won the following drawings:<br />\n";
  echo "<table border=1>\n";
  echo "<tr>\n";
  echo "<th>Draw date</th>\n";
  echo "<th>#1</th>\n";
  echo "<th>#2</th>\n";
  echo "<th>#3</th>\n";
  echo "<th>#4</th>\n";
  echo "<th>#5</th>\n";
  echo "<th>Type of win</th>\n";
  echo "<th>Paid</th>\n";
  echo "</tr>\n";

  while ( $winner=mysql_fetch_array($winners) ) {
    // Verify the winning number falls within this number's validity period
    if ( strtotime($player['added']) < strtotime($winner['date']) &&
         ( $player['voided'] == "" ||
           strtotime($player['voided']) > strtotime($winner['date']) ) ) {
      // Add up the matches
      $straightMatch = 0;
      $boxMatch = 0;
      if ( $winner['num1'] == $player['num1'] ) {
        $straightMatch++;
        $boxMatch++;
      }
      else if ( $winner['num1'] == $player['num2'] ||
                $winner['num1'] == $player['num3'] ||
                $winner['num1'] == $player['num4'] ||
                $winner['num1'] == $player['num5'] ) {
        $boxMatch++;
      }
      if ($winner['num2'] == $player['num2']) {
        $straightMatch++;
        $boxMatch++;
      }
      else if ( $winner['num2'] == $player['num1'] ||
                $winner['num2'] == $player['num3'] ||
                $winner['num2'] == $player['num4'] ||
                $winner['num2'] == $player['num5'] ) {
        $boxMatch++;
      }
      if ($winner['num3'] == $player['num3']) {
        $straightMatch++;
        $boxMatch++;
      }
      else if ( $winner['num3'] == $player['num1'] ||
                $winner['num3'] == $player['num2'] ||
                $winner['num3'] == $player['num4'] ||
                $winner['num3'] == $player['num5'] ) {
        $boxMatch++;
      }
      if ($winner['num4'] == $player['num4']) {
        $straightMatch++;
        $boxMatch++;
      }
      else if ( $winner['num4'] == $player['num1'] ||
                $winner['num4'] == $player['num2'] ||
                $winner['num4'] == $player['num3'] ||
                $winner['num4'] == $player['num5'] ) {
        $boxMatch++;
      }
      if ($winner['num5'] == $player['num5']) {
        $straightMatch++;
        $boxMatch++;
      }
      else if ( $winner['num5'] == $player['num1'] ||
                $winner['num5'] == $player['num2'] ||
                $winner['num5'] == $player['num3'] ||
                $winner['num5'] == $player['num4'] ) {
        $boxMatch++;
      }
  
      // Print winning numbers that matched
      if ( $straightMatch >= 3 ||
           $boxMatch      >= 3    ) {
        echo "<tr>\n";
        echo "<td>" . $winner['date'] . "</td>\n";
        echo "<td>" . $winner['num1'] . "</td>\n";
        echo "<td>" . $winner['num2'] . "</td>\n";
        echo "<td>" . $winner['num3'] . "</td>\n";
        echo "<td>" . $winner['num4'] . "</td>\n";
        echo "<td>" . $winner['num5'] . "</td>\n";
        // Determine the type of win
        if ( $straightMatch == 5 ) {
          echo "<td>Straight 5</td>";
        } else if ( $straightMatch == 4 ) {
          echo "<td>Straight 4</td>";
        } else if ( $boxMatch == 5 ) {
          echo "<td>Boxed 5</td>";
        } else if ( $straightMatch == 3 ) {
          echo "<td>Straight 3</td>";
        } else if ( $boxMatch == 4 ) {
          echo "<td>Boxed 4</td>";
        } else if ( $boxMatch == 3 ) {
          echo "<td>Boxed 3</td>";
        } else {
          echo "<td>Unknown</td>";
        }
        if ( isPaid($player['id'], $winner['id']) ) {
          echo "<td align='center'>X</td>\n";
        } else {
          echo "<td></td>\n";
        }
        echo "</tr>\n";
      }
    }
  } // End if - time validity check
  echo "</table>\n";
  echo "<a href=''>Click here to refresh the page.</a><br />\n";
}

connect();
?>

<html>
<head>
  <title>Leopold Lotto Administration</title>
</head>
<body>
<script>
function randomWin() {
  var n1, n2, n3, n4, n5;
  n1 = Math.floor(Math.random()*25)+1;
  while ( true ) {
    n2 = Math.floor(Math.random()*25)+1;
    if ( n2 != n1 )
      break;
  }
  while ( true ) {
    n3 = Math.floor(Math.random()*25)+1;
    if ( n3 != n1 &&
         n3 != n2 )
      break;
  }
  while ( true ) {
    n4 = Math.floor(Math.random()*25)+1;
    if ( n4 != n1 &&
         n4 != n2 &&
         n4 != n3 )
      break;
  }
  while ( true ) {
    n5 = Math.floor(Math.random()*25)+1;
    if ( n5 != n1 &&
         n5 != n2 &&
         n5 != n3 &&
         n5 != n4 )
      break;
  }
  document.getElementsByName("winNum1")[0].value = n1;
  document.getElementsByName("winNum2")[0].value = n2;
  document.getElementsByName("winNum3")[0].value = n3;
  document.getElementsByName("winNum4")[0].value = n4;
  document.getElementsByName("winNum5")[0].value = n5;
}

function randomPlay() {
  var n1, n2, n3, n4, n5;
  n1 = Math.floor(Math.random()*25)+1;
  while ( true ) {
    n2 = Math.floor(Math.random()*25)+1;
    if ( n2 != n1 )
      break;
  }
  while ( true ) {
    n3 = Math.floor(Math.random()*25)+1;
    if ( n3 != n1 &&
         n3 != n2 )
      break;
  }
  while ( true ) {
    n4 = Math.floor(Math.random()*25)+1;
    if ( n4 != n1 &&
         n4 != n2 &&
         n4 != n3 )
      break;
  }
  while ( true ) {
    n5 = Math.floor(Math.random()*25)+1;
    if ( n5 != n1 &&
         n5 != n2 &&
         n5 != n3 &&
         n5 != n4 )
      break;
  }
  document.getElementsByName("playerNum1")[0].value = n1;
  document.getElementsByName("playerNum2")[0].value = n2;
  document.getElementsByName("playerNum3")[0].value = n3;
  document.getElementsByName("playerNum4")[0].value = n4;
  document.getElementsByName("playerNum5")[0].value = n5;
}
</script>
<h1>Testing page</h1><hr />
<!---------------------------- List winning numbers --------------------------->
<p>
Winning numbers to date:<br />
<form name="winners" method="POST">
<table border=1>
<tr>
  <th></th>
  <th>Date</th>
  <th>#1</th>
  <th>#2</th>
  <th>#3</th>
  <th>#4</th>
  <th>#5</th>
</tr>
<?php
$winners = getWinners();
while ( $winner=mysql_fetch_array($winners) ) {
  echo "<tr>\n";
  echo "<td><input type='radio' name='winnerID' value='". $winner['id'] ."' /></td>\n";
  echo "<td>" . $winner['date'] . "</td>\n";
  echo "<td>" . $winner['num1'] . "</td>\n";
  echo "<td>" . $winner['num2'] . "</td>\n";
  echo "<td>" . $winner['num3'] . "</td>\n";
  echo "<td>" . $winner['num4'] . "</td>\n";
  echo "<td>" . $winner['num5'] . "</td>\n";
  echo "</tr>\n";
}
?>
</table>
<input type="submit" value="Delete" action="." name="deleteWinner" />
<input type="submit" value="Find Winners" action="." name="showMatches" />
</form>
</p>

<?php
if (isset($_POST['deleteWinner']))
  deleteWinner();

if (isset($_POST['showMatches']))
  showMatches();

if (isset($_POST['pay']))
  markPaidPlayers();
?>


<!-------------- Add new winning numbers -------------->
<p>
Enter new set of winning numbers:<br />
<form id="newWin" name="addWinner" method="POST">
<table border=1>
<tr>
  <th>Date (Optional)</th>
  <th>#1</th>
  <th>#2</th>
  <th>#3</th>
  <th>#4</th>
  <th>#5</th>
</tr>
<tr>
  <td><input type="text" size="20" name="date" /></td>
  <td><input type="text" size="2" name="winNum1" /></td>
  <td><input type="text" size="2" name="winNum2" /></td>
  <td><input type="text" size="2" name="winNum3" /></td>
  <td><input type="text" size="2" name="winNum4" /></td>
  <td><input type="text" size="2" name="winNum5" /></td>
</tr>
</table>
<input type="submit" value="Add" action="." name="addWinner" />
<input type="button" value="Randomize" onClick="randomWin()" />
</form>
</p>

<?php
if (isset($_POST['addWinner']))
  addWinner();
?>



<!----------------- List player numbers ------------------------>
<hr />
<p>
Player numbers:<br />
<form name="winners" method="POST">
<table border=1>
<tr>
  <th></th>
  <th>Added</th>
  <th>Voided</th>
  <th>#1</th>
  <th>#2</th>
  <th>#3</th>
  <th>#4</th>
  <th>#5</th>
  <th>Player</th>
</tr>
<?php
$players = getPlayers(0);
while ( $player=mysql_fetch_array($players) ) {
  echo "<tr>\n";
  echo "<td><input type='radio' name='playerID' value='". $player['id'] ."' /></td>\n";
  echo "<td>" . $player['added'] . "</td>\n";
  echo "<td>" . $player['voided'] . "</td>\n";
  echo "<td>" . $player['num1'] . "</td>\n";
  echo "<td>" . $player['num2'] . "</td>\n";
  echo "<td>" . $player['num3'] . "</td>\n";
  echo "<td>" . $player['num4'] . "</td>\n";
  echo "<td>" . $player['num5'] . "</td>\n";
  echo "<td>" . $player['name'] . "</td>\n";
  echo "</tr>\n";
}
?>
</table>
<input type="submit" value="Delete"        action="." name="deletePlayer" />
<input type="submit" value="Check for win" action="." name="checkIfWinner" />
</form>
</p>

<?php
if ( isset($_POST['deletePlayer']))
  deletePlayer();

if ( isset($_POST['checkIfWinner']))
  checkIfWinner();
?>




<!-------------- Add/Set new player numbers -------------->
<p>
Enter player name and their new numbers:<br />
<form id="newPlayer" name="setPlayer" method="POST">
<table border=1>
<tr>
  <th>Player</th>
  <th>#1</th>
  <th>#2</th>
  <th>#3</th>
  <th>#4</th>
  <th>#5</th>
</tr>
<tr>
  <td><input type="text" size="20" name="playerName" /></td>
  <td><input type="text" size="2" name="playerNum1" /></td>
  <td><input type="text" size="2" name="playerNum2" /></td>
  <td><input type="text" size="2" name="playerNum3" /></td>
  <td><input type="text" size="2" name="playerNum4" /></td>
  <td><input type="text" size="2" name="playerNum5" /></td>
</tr>
</table>
<input type="submit" value="Add" action="." name="newPlayer" />
<input type="button" value="Randomize" onClick="randomPlay()" />
</form>
</p>

<?php
if (isset($_POST['newPlayer']))
  addPlayer();
?>

</body>
</html>




