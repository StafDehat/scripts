#!/bin/bash -x

# Author: Andrew Howard

echo -n "  Installing SNMP..."
if [[ `rpm -q net-snmp | grep -v "not installed" | wc -l` -gt 0 ]]; then
	echo "SNMP already installed!"
	exit 0
fi

if [ -f /etc/yum.conf ]; then
  yum -d 1 -y install net-snmp 1>&2
elif [ -f /var/log/up2date ]; then
  up2date net-snmp 1>&2
else
  echo "Error: Unable to install net-snmp!"
  exit 255
fi
echo "done!"

echo -n "  Configuring SNMP..."
wget -P /tmp http://SERVER/snmp/top.conf -o /dev/null
wget -P /tmp http://SERVER/snmp/bottom.conf -o /dev/null
cat /tmp/top.conf > /etc/snmp/snmpd.conf
df | grep /dev | grep -v /dev/shm | awk '{print $6}' | sed s/^/"disk "/ >> /etc/snmp/snmpd.conf
cat /tmp/bottom.conf >> /etc/snmp/snmpd.conf
rm -f /tmp/top.conf /tmp/bottom.conf
echo "done!"

echo -n "  Adding SNMP to startup process and restarting..."
chkconfig snmpd on
/etc/init.d/snmpd start 1>&2
echo "done!"

if [ -d /var/cpanel ]; then
  echo -n "  Adding SNMP to chkservd..."
  echo "service[snmpd]=x,x,x,/etc/init.d/snmpd restart,snmpd,root" > /etc/chkserv.d/snmpd && echo "snmpd:1" >> /etc/chkserv.d/chkservd.conf
  /etc/init.d/chkservd restart 1>&2
  echo "done!"
fi

echo "  SNMP installed successfully."
