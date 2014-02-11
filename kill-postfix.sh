#!/bin/bash

# Start a process to kill postfix forcefully in 5 minutes
PID=`cat /var/spool/postfix/pid/master.pid`
ChildPIDS=$(pgrep -P $PID)
(sleep 300 && kill -9 $ChildPIDS) &
KillerPID=$!

# Attempt to stop postfix gracefully now
/sbin/service postfix stop

# If postfix stopped gracefully, stop our forceful kill from running in 5 minutes
if [ ! -e /var/spool/postfix/pid/master.pid ]; then kill $KillerPID; fi

# Wait for the forceful kill process to terminate, whether that be by killing postfix in 5 minutes, or by being stopped by the above 'if' command
wait $KillerPID 2>/dev/null
