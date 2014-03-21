#!/bin/bash

# Author: Andrew Howard
# Work in progress.  Goal is to print all cronjobs, sorted by times they fire.

cat \
  <(cat /var/spool/cron/* | grep -vE '(^\s*$|^\#|^SHELL|^PATH|^MAILTO|^HOME)') \
  <(cat /etc/cron.d/* | grep -vE '(^\s*$|^\#|^SHELL|^PATH|^MAILTO|^HOME)')
