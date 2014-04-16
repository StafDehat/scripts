<?php
function time2secs($str_time) {
  $str_time = preg_replace("/^([\d]{1,2})\:([\d]{2})$/", "00:$1:$2", $str_time);
  sscanf($str_time, "%d:%d:%d", $hours, $minutes, $seconds);
  $time_seconds = $hours * 3600 + $minutes * 60 + $seconds;
  return $time_seconds;
}
?>
