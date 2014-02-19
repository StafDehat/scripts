<?php
  if (isset($_POST['submit'])) {
    $label      = $_POST["label"];
    $startday   = $_POST["startday"];
    $startmonth = $_POST["startmonth"];
    $startyear  = $_POST["startyear"];
    $stopday    = $_POST["stopday"];
    $stopmonth  = $_POST["stopmonth"];
    $stopyear   = $_POST["stopyear"];
    $forelines  = $_POST["forelines"];
    $aftlines   = $_POST["aftlines"];
  } else {
    $label      = "";
    $startday   = date("d");
    $startmonth = date("M");
    $startyear  = date("Y");
    $stopday    = date("d");
    $stopmonth  = date("M");
    $stopyear   = date("Y");
    $forelines  = 0;
    $aftlines   = 0;
  }

  $months[0] = "Jan";
  $months[1] = "Feb";
  $months[2] = "Mar";
  $months[3] = "Apr";
  $months[4] = "May";
  $months[5] = "Jun";
  $months[6] = "Jul";
  $months[7] = "Aug";
  $months[8] = "Sep";
  $months[9] = "Oct";
  $months[10] = "Nov";
  $months[11] = "Dec";
?>

<html>
<head>
  <title>Shift Log</title>
</head>
<body>
  <form name='form1' action='' method='post'>
    <table>
      <tr>
        <td>Search String:</td>
        <td><input type="text" name="label" value="<?php echo "$label" ?>" /> - Leave blank to see all logs</td>
      </tr>
      <tr>
        <td>Search from:</td>
        <td>
          <select name="startmonth">
<?php
  for ( $month = 0; $month < 12; $month += 1 ) {
    echo "            <option value='". $months[$month] ."'";
    if ( $months[$month] == $startmonth )
      echo " selected";
    echo ">". $months[$month] ."</option>\n";
  }
?>
          </select>
          <select name="startday">
<?php
  for ( $day = 1; $day <= 31; $day += 1) {
    echo "            <option value='$day'";
    if ( $startday == $day )
      echo " selected";
    echo ">$day</option>\n";
  }
?>
          </select>
          <input type="text" maxlength="4" size="4" name="startyear" value="<?php echo $startyear ?>" />
        </td>
      </tr>
      <tr>
        <td>Search until:</td>
        <td>
          <select name="stopmonth">
<?php
  for ( $month = 0; $month < 12; $month += 1 ) {
    echo "            <option value='". $months[$month] ."'";
    if ( $months[$month] == $stopmonth )
      echo " selected";
    echo ">". $months[$month] ."</option>\n";
  }
?>
          </select>
          <select name="stopday">
<?php
  for ( $day = 1; $day <= 31; $day += 1) {
    echo "            <option value='$day'";
    if ( $stopday == $day )
      echo " selected";
    echo ">$day</option>\n";
  }
?>

          </select>
          <input type="text" maxlength="4" size="4" name="stopyear" value="<?php echo $stopyear ?>" />
        </td>
      </tr>
      <tr>
        <td>Preceding lines of context:</td>
        <td><input type="text" maxlength="2" size="2" name="forelines" value="<?php echo $forelines ?>" /></td>
      </tr>
      <tr>
        <td>Following lines of context:</td>
        <td><input type="text" maxlength="2" size="2" name="aftlines" value="<?php echo $aftlines ?>" /></td>
      </tr>
    </table>
    <input type="submit" value="Grep!" name="submit" />
  </form>

<?php
  if (isset($_POST['submit'])) {
    $logdir = "/usr/local/inspircd/eggdrop/logs/shiftlog";

    $label = $_POST["label"];
    $startdate = $_POST["startmonth"] ." ". $_POST["startday"] ." ". $_POST["startyear"];
    $stopdate = $_POST["stopmonth"] ." ". $_POST["stopday"] ." ". $_POST["stopyear"];
    $forelines = $_POST["forelines"];
    $aftlines = $_POST["aftlines"];

    $startepoch = strtotime($startdate);
    $stopepoch = strtotime($stopdate);
    $nowepoch = time();

    $current = $startepoch;
    $label = escapeshellcmd($label);
    $forelines = escapeshellcmd($forelines);
    $aftlines = escapeshellcmd($aftlines);
    if (empty($forelines)) $forelines = 0;
    if (empty($aftlines)) $aftlines = 0;

    while ( $current <= $stopepoch && $current < $nowepoch ) {
      $logfile=$logdir . "/shiftlog.log.". date("dMY", $current);

      if (file_exists($logfile)) {
        echo "<hr />\n";
        echo date("D M d, Y", $current) ."<br />\n";

        echo "<pre>\n";
        ob_start();
        passthru("grep -i -B $forelines -A $aftlines '$label' $logfile", $outflag);
        $output=ob_get_contents();
        ob_end_clean();
        if ($outflag == 0)
          echo htmlentities($output);
        echo "</pre>\n";
      } else {
        echo "<hr />\n";
        echo "No logfile for ". date("D M d, Y", $current) ."<br />\n";
      }

      // Increment 24 hours, to next logfile
      $current += 86400;
    }
  }
?>
</body>
</html>

