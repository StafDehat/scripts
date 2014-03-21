#!/bin/bash

# Author: Andrew Howard

MODEL=5510

echo "Welcome!  Let's configure an asa5510!"
echo "(Not a 5510?  Probably don't want this guide)"
echo ""

echo -e "I need information about the \033[1mSERVER\033[0m"
read -p "Customer's domain (rootmypc.net): " DOMAIN
read -p "Primary server (server1): " HOSTNAME
read -p "Allocated netblock (64.38.17.0/29): " ALLOCATION
read -p "Open TCP ports? (21,25,80,443): " TCPORTS
read -p "Open UDP ports? (20,21,53,161): " UDPORTS
echo ""
echo -e "Now some info about the \033[1mFIREWALL\033[0m"
read -p "ASA public netblock (64.38.17.120/30): " ASAIP
read -p "ASA password (abc@123): " PASS

CIDR=`echo $ASAIP | cut -d/ -f2`
if [[ $CIDR -ne 30 ]]; then
  echo "WTF.  Give the ASA a /30 and then we'll talk."
  exit 0
fi
CIDR=`echo $ALLOCATION | cut -d/ -f2`
NUMIPS=`echo "2^(32-$CIDR)-3" | bc`
BASE=`echo $ALLOCATION | cut -d/ -f1 | cut -d. -f4`
EXTC=`echo $ALLOCATION | cut -d. -f1-3`.
INTC=10.`echo "$RANDOM % 255" | bc`.`echo $EXTC | cut -d. -f3`.

echo ""
echo -e "\033[1mPrepare thyself for an initial asa5510 config\033[0m"
echo -e "\033[1m==================================================\033[0m"
echo "en"
echo "config t"
echo "enable password $PASS"
echo "password $PASS"
echo "hostname asa$MODEL"
echo "domain-name $DOMAIN"


ASA4=`echo $ASAIP | cut -d. -f4 | cut -d/ -f1`
ASAC=`echo $ASAIP | cut -d. -f1-3`.

echo "interface eth 0/0"
echo "nameif outside"
echo "security-level 0"
echo "ip address `echo $ASAC$((ASA4+2))` 255.255.255.252"
echo "no shutdown"
echo "exit"

echo "interface eth 0/1"
echo "nameif inside"
echo "security-level 100"
echo "ip address `echo $INTC | cut -d. -f1,2`.0.1 255.255.0.0"
echo "no shutdown"
echo "exit"

echo "interface Ethernet0/0"
echo "switchport access vlan 2"
echo "no shutdown"
echo "interface Ethernet0/1"
echo "no shutdown"
echo "interface Ethernet0/2"
echo "no shutdown"
echo "interface Ethernet0/3"
echo "no shutdown"
echo "interface Ethernet0/4"
echo "no shutdown"
echo "interface Ethernet0/5"
echo "no shutdown"
echo "interface Ethernet0/6"
echo "no shutdown"
echo "interface Ethernet0/7"
echo "no shutdown"
echo "exit"

echo "route outside 0.0.0.0 0.0.0.0 $ASAC$((ASA4+1)) 1"


echo "names"
for x in `seq 1 $NUMIPS`; do
  echo "name $EXTC$(($BASE+1+$x)) $HOSTNAME.ext$x"
done

echo "object-group network FS_STAFF"
WHITELIST=`curl http://SERVER/fsofficesubnets.txt 2> /dev/null`
for x in $WHITELIST; do
  TEMPCIDR=`echo $x | cut -d/ -f2`
  IPADDR=`echo $x | cut -d/ -f1`
  NETMASK=255.255.255.`echo "256-2^(32-$TEMPCIDR)" | bc`
  echo "network-object $IPADDR $NETMASK"
done
echo "exit"

HOSTGROUP=`echo $HOSTNAME | tr a-z A-Z`

echo "object-group service ${HOSTGROUP}_TCP tcp"
for x in `echo $TCPORTS | sed 's/,/ /g'`; do
  echo "port-object eq $x"
done
echo "exit"

echo "object-group service ${HOSTGROUP}_UDP udp"
for x in `echo $UDPORTS | sed 's/,/ /g'`; do
  echo "port-object eq $x"
done
echo "exit"

echo "object-group network $HOSTGROUP"
for x in `seq 1 $NUMIPS`; do
  echo "network-object host $HOSTNAME.ext$x"
done
echo "exit"


echo "access-list outside_access_in remark Staff gets through free"
echo "access-list outside_access_in permit ip object-group FS_STAFF any"
echo "access-list outside_access_in permit tcp any object-group $HOSTGROUP object-group ${HOSTGROUP}_TCP"
echo "access-list outside_access_in permit udp any object-group $HOSTGROUP object-group ${HOSTGROUP}_UDP"

echo "access-list outside_access_in permit icmp host 64.62.137.55 any"
echo "access-list outside_access_in permit icmp host 74.200.192.133 any"
echo "access-list outside_access_in permit icmp host 64.38.5.242 any"

echo "access-group outside_access_in in interface outside"


NETMASK=255.255.255.`echo "256-2^(32-$CIDR)" | bc`
echo "static (inside,outside) $EXTC$BASE $INTC$BASE netmask $NETMASK 0 0"


echo "aaa-server TACACS+ protocol tacacs+"
echo "aaa-server TACACS+ max-failed-attempts 3"
echo "aaa-server TACACS+ deadtime 10"
echo "aaa-server RADIUS protocol radius"
echo "aaa-server RADIUS max-failed-attempts 3"
echo "aaa-server RADIUS deadtime 10"


echo "http server enable"
for x in $WHITELIST; do
  TEMPCIDR=`echo $x | cut -d/ -f2`
  IPADDR=`echo $x | cut -d/ -f1`
  NETMASK=255.255.255.`echo "256-2^(32-$TEMPCIDR)" | bc`
  echo "http $IPADDR $NETMASK outside"
done
echo "http `echo $INTC | cut -d. -f1,2`.0.1 255.255.0.0 inside"

for x in $WHITELIST; do
  TEMPCIDR=`echo $x | cut -d/ -f2`
  IPADDR=`echo $x | cut -d/ -f1`
  NETMASK=255.255.255.`echo "256-2^(32-$TEMPCIDR)" | bc`
  echo "ssh $IPADDR $NETMASK outside"
done
echo "ssh `echo $INTC | cut -d. -f1,2`.0.1 255.255.0.0 inside"

echo "crypto key generate rsa modulus 1024"
echo "write mem"







