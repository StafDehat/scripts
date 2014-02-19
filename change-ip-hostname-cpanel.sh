#!/bin/bash


read -p "Old/Current IP: " OLDIP
read -p "Old/Current Hostname: " OLDNAME


# Set hostname
read -p "New Hostname: " SERVERNAME

hostname $SERVERNAME

echo "NETWORKING=yes
HOSTNAME=$SERVERNAME" > /etc/sysconfig/network

for x in /etc/httpd/conf/*; do
  sed -i "s/$OLDNAME/$SERVERNAME/g" $x
done
for x in /etc/*; do
  sed -i "s/$OLDNAME/$SERVERNAME/g" $x
done
sed -i "s/$OLDNAME/$SERVERNAME/g" /etc/sysconfig/rhn/systemid
for x in `grep -lR $OLDNAME /var/cpanel`; do
  sed -i "s/$OLDNAME/$SERVERNAME/g" $x
done
for x in /var/named/*; do
  sed -i "s/$OLDNAME/$SERVERNAME/g" $x
done

mv /var/cpanel/userdata/nobody/$OLDNAME /var/cpanel/userdata/nobody/$SERVERNAME


# Set base IP
read -p "New Base IP: " IPADDR
read -p "New Subnet mask: " NETMASK
read -p "New Gateway address: " GATEWAY

echo "DEVICE=eth0
BOOTPROTO=static
IPADDR=$IPADDR
NETMASK=$NETMASK
ONBOOT=yes
TYPE=Ethernet" > /etc/sysconfig/network-scripts/ifcfg-eth0

echo "GATEWAY=$GATEWAY" >> /etc/sysconfig/network

sed -i "s/$OLDIP/$IPADDR/g" /var/cpanel/users/*
for x in /var/cpanel/userdata/*; do
  sed -i "s/$OLDIP/$IPADDR/g" $x/*
done
for x in /etc/httpd/conf/*; do
  sed -i "s/$OLDIP/$IPADDR/g" $x
done
for x in /etc/httpd/conf/sites/*; do
  sed -i "s/OLDIP/$IPADDR/g" $x
done
for x in /etc/*; do
  sed -i "s/$OLDIP/$IPADDR/g" $x
done
/scripts/updateuserdomains
/scripts/updatedomainips
/scripts/updateuserdomains

/etc/init.d/network restart
/etc/init.d/ipaliases reload

/usr/local/cpanel/cpkeyclt

