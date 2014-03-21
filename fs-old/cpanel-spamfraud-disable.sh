#!/bin/bash

# Author: Andrew Howard

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/usr/local/bin:/root/bin

#
# Delete the queue.  We only want new spam.
#exim -bpru | awk {'print $3'} | xargs exim -Mrm >/dev/null

#
# Test for log_selector line.  If absent, add.
if [[ `cat /etc/exim.conf` =~ "log_selector" ]]; then
  echo "log_selector line already present in exim.conf"
else
  echo "log_selector line not present in exim.conf - adding and restarting"
  sed -i '2s/^/log_selector = +address_rewrite +all_parents +arguments +connection_reject +delay_delivery +delivery_size +dnslist_defer +incoming_interface +incoming_port +lost_incoming_connection +queue_run +received_sender +received_recipients +retry_defer +sender_on_delivery +size_reject +skip_delivery +smtp_confirmation +smtp_connection +smtp_protocol_error +smtp_syntax_error +subject +tls_cipher +tls_peerdn\n/' /etc/exim.conf
  /etc/init.d/exim restart
  if [ $? -ne 0 ]; then
    echo Failed to restart exim
    exit 1
  fi
fi

#
# Build some logs.  Find the offending user.  Verify it's a user.
sleep 10
USERNAME=`tail -500 /var/log/exim_mainlog | grep cwd | grep -v /var/spool/exim | sed 's/^.*cwd=\/home\/\(.*\)\/public_html.*$/\1/' | sort | uniq -c | sort -n | tail -1 | awk '{print $2}'`
if [ -z $USERNAME ]; then
  echo Unable to determine abusive user
  exit 1
fi
if [[ `cat /etc/trueuserdomains` =~ $USERNAME ]]; then
  echo Abusive user is $USERNAME
else
  echo Unable to determine abusive user
  exit 1
fi

#
# See if account is exclusively for spamming
if [ `du -s /home/$USERNAME | awk '{print $1}'` -lt 1000 ]; then
  /scripts/suspendacct $USERNAME
else
  echo Abusive user has domain content - can not in good conscience suspend account.
  exit 1
fi

#
# Clear mail queue for good measure
/etc/init.d/httpd restart
exim -bpru | awk {'print $3'} | xargs exim -Mrm >/dev/null

#
# Generate report
USERDOMAIN=`grep $USERNAME /etc/trueuserdomains | awk -F : '{print $1}'`
SERVER=`hostname`
echo EMAILADDR com
CC: EMAILADDR net; EMAILADDR com; EMAILADDR com; EMAILADDR com
BCC: EMAILADDR net
Subject: Suspended account: $USERNAME
Greetings,

I've suspended the account '$USERNAME' ($USERDOMAIN) on $SERVER for spamming, as it appears the account was created exclusively for this purpose.

.
"

# EMAILADDR net" -t
#echo Notification email has been sent

