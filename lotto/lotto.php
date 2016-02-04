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

function getPlayerHistory() {
  extract($_POST);
  $query = "SELECT * FROM players WHERE name = '". $playerName ."' ORDER BY name, added";
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
    $query = "INSERT INTO winners(date, num1, num2, num3, num4, num5)
              VALUES(NOW(),
                '" . intval($winNum1) . "',
                '" . intval($winNum2) . "',
                '" . intval($winNum3) . "',
                '" . intval($winNum4) . "',
                '" . intval($winNum5) . "')";
    echo "New winning numbers (".intval($winNum1)."-".intval($winNum2)."-".intval($winNum3)."-".intval($winNum4)."-".intval($winNum5).") added.<br />\n";
    echo "<a href=''>Click here to refresh the page.</a><br />\n";
    mysql_query($query) OR die("Unable to add numbers: ". mysql_error());
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
      echo "</tr>\n";
      $count++;
    }
  }
  echo "</table>\n";
  echo "Total winners: ". $count ."<br />\n";
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

//
// Establish a connection to the database
connect();



/************************************* Start of HTML ***********************************/
?>
<html>
<head>
  <title>Leopold Lotto Checker</title>
</head>
<body>
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
<input type="submit" value="Who won?" action="." name="showMatches" />
</form>
</p>

<?php
if (isset($_POST['showMatches']))
  showMatches();
?>




<!--------------- View numbers history for Player ------------------->
<hr />
<p>
Enter your character name to see your numbers, and check if you won:<br />
<form name="playerQuery" method="POST">
<input type="text" name="playerName" />
<input type="submit" value="Lookup" action="." name="playerQuery" />
</form>

<?php
if (isset($_POST['playerQuery'])) {
  $players = getPlayerHistory();
  echo "<form name='playerHistory' method='POST'>\n";
  echo "<table border=1>\n";
  echo "<tr>\n";
  echo "  <th></th>\n";
  echo "  <th>Added</th>\n";
  echo "  <th>Voided</th>\n";
  echo "  <th>#1</th>\n";
  echo "  <th>#2</th>\n";
  echo "  <th>#3</th>\n";
  echo "  <th>#4</th>\n";
  echo "  <th>#5</th>\n";
  echo "  <th>Player</th>\n";
  echo "</tr>\n";
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
  echo "</table>\n";
  echo "<input type='submit' value='Check for win' action='.' name='checkIfWinner' />\n";
  echo "</form>\n";
}
?>
</p>

<?php
if ( isset($_POST['checkIfWinner']))
  checkIfWinner();
?>




</body>
</html>




