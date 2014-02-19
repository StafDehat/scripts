#!/usr/bin/php
<?php
if ( $_SERVER['argc'] != 2 ) {
  print "Error: Incorrect number of arguments\n";
  print "Usage: ./time.php _TIME_\n";
  print "  _TIME_: Seconds since epoch (ie: 1229552335)\n";
  exit();
}

print date("Y-m-d H:i:s", $_SERVER['argv'][1]) . "\n";

?>

