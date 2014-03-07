<!-- MySQL requirements:
GRANT UPDATE ON intranet.ipallocate TO reallocate@localhost IDENTIFIED BY '...';
GRANT SELECT ON intranet.ipallocate TO reallocate@localhost IDENTIFIED BY '...';
GRANT SELECT ON intranet.server TO reallocate@localhost IDENTIFIED BY '...';
-->
<?php
  function errorOut($message) {
    echo "<hr />\n";
    exit($message);
  }

  $dbserver = "";
  $dbuser = "";
  $dbpass = "~";
  $database = "";

  $serverAID = $_POST["serverAID"];
  $serverBID = $_POST["serverBID"];
  $serverALabel = $_POST["serverALabel"];
  $serverBLabel = $_POST["serverBLabel"];
?>
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
  <style type="text/css">
    #instructions
    {
      width: 15em;
      float: right;
      margin-right: 1em;
      margin-left: 1em;
    }
  </style>
  <title>Allocation Swap</title>
</head>
<body>
  <h1>Allocation Swap</h1>

  <div id="instructions">
    <h2>Instructions</h2>
    <b>Step 1:</b><br />
    Enter the 'Server ID' of each server involved in the swap.
    It doesn't matter which is Server A and which is Server B.
    You'll determine which allocations go where in step 2.
    Click Fetch!<br />
    <b>Step 2:</b><br />
    Check the box for each allocation that should be swapped.
    Only the allocations that are checked will be swapped, all others will remain un-touched.
    Click Swap!<br />
  </div>

  <!-- -- -- -- -- -- Fetch portion -- -- -- -- -- -->
  <form name="enumerate" action="" method="post">
    <table>
      <tr>
        <td>Server A ID: </td>
        <td><input type="text" name="serverAID" value="<?php echo $serverAID; ?>" /></td>
      </tr>
      <tr>
        <td>Server B ID: </td>
        <td><input type="text" name="serverBID" value="<?php echo $serverBID; ?>" /></td>
      </tr>
    </table>
    <input type="submit" value="Fetch!" name="submit1" />
  </form>


  <!-- -- -- -- -- -- List portion -- -- -- -- -- -->
<?php
if (isset($_POST['submit1'])) {
  mysql_connect($dbserver, $dbuser, $dbpass) or die(mysql_error());
  mysql_select_db($database) or die(mysql_error());

  $result = mysql_query("SELECT label FROM server WHERE server_id = '$serverAID';");
  $row = mysql_fetch_array($result);
  if ( ! $row )
    errorOut("Server A ID not a valid Server ID");
  $serverALabel = $row["label"];

  $result = mysql_query("SELECT label FROM server WHERE server_id = '$serverBID';");
  $row = mysql_fetch_array($result);
  if ( ! $row )
    errorOut("Server B ID not a valid Server ID");
  $serverBLabel = $row["label"];

  echo "  <hr>\n";
  echo "  <form name='reallocate' action='' method='post'>\n";
  echo "    <input type='hidden' name='serverAID' value='". $serverAID ."' />\n";
  echo "    <input type='hidden' name='serverBID' value='". $serverBID ."' />\n";
  echo "    <input type='hidden' name='serverALabel' value='". $serverALabel ."' />\n";
  echo "    <input type='hidden' name='serverBLabel' value='". $serverBLabel ."' />\n";
  echo "    <b>Server A: ". $serverAID ." (". $serverALabel .")</b><br />\n";
  $result = mysql_query("SELECT ip_id, ip, bitmask FROM ipallocate WHERE server_id = '$serverAID';");
  while ($row = mysql_fetch_array( $result )) {
    echo "      <input type='checkbox' name='assign". $row["ip_id"] ."to". $serverBID ."' />";
    echo long2ip($row["ip"]) ."/". $row["bitmask"] . "<br />\n";
  }
  echo "    <b>Server B: ". $serverBID ." (". $serverBLabel .")</b><br />\n";
  $result = mysql_query("SELECT ip_id, ip, bitmask FROM ipallocate WHERE server_id = '$serverBID';") or die(mysql_error());
  while ($row = mysql_fetch_array( $result )) {
    echo "      <input type='checkbox' name='assign". $row["ip_id"] ."to". $serverAID ."' />";
    echo long2ip($row["ip"]) ."/". $row["bitmask"] . "<br />\n";
  }
  echo "    <input type='submit' name='submit2' value='Swap!' />\n";
  echo "  </form>\n";
} ?>


  <!-- -- -- -- -- -- Verification portion -- -- -- -- -- -->
<?php

?>


  <!-- -- -- -- -- -- Swap portion -- -- -- -- -- -->
<?php
if (isset($_POST['submit2'])) {
  mysql_connect($dbserver, $dbuser, $dbpass) or die(mysql_error());
  mysql_select_db($database) or die(mysql_error());

  echo "  <hr>\n";
  $keys = array_keys($_POST);
  foreach($keys as $key) {
    if ( $_POST[$key] == "on" ) {
      preg_match('/^assign(\d+)to(\d+)$/', $key, $match);

      // Make the output pretty - Labels and netblocks instead of Server/IP IDs
      if ( $match[2] == $serverAID ) $server = $serverALabel;
      else $server = $serverBLabel;
      $result = mysql_query("SELECT ip, bitmask FROM ipallocate WHERE ip_id = '". $match[1] ."';") or die(mysql_error());
      $row = mysql_fetch_array( $result );
      $netblock = long2ip($row["ip"]) ."/". $row["bitmask"];

      echo "  Assigned ". $netblock ." to ". $server ."<br />\n";
      mysql_query("UPDATE ipallocate SET server_id = '". $match[2] ."' WHERE ip_id = '". $match[1] ."';")
        or die(mysql_error());
    }
  }
  echo "  Swap complete.<br />\n";
}
?>
</body>
</html>

