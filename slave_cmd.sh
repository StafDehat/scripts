#!/bin/bash

MYSQL=/usr/bin/mysql

start_slave() {
   $MYSQL -sse 'set global innodb_max_dirty_pages_pct=60;' &> /dev/null || true
   $MYSQL -sse 'start slave;' &> /dev/null || true
}

stop_slave() {
   $MYSQL -sse 'set global innodb_max_dirty_pages_pct=90;' &> /dev/null || true
   $MYSQL -sse 'stop slave;' &> /dev/null || true
   sleep 900 &> /dev/null || true
}

case "$1" in
    start)   start_slave ;;
    stop)    stop_slave ;;
    restart) stop_slave; start_slave ;;
    *) echo "usage: $0 start|stop|restart" >&2
       exit 1
       ;;
esac

