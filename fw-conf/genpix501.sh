#!/bin/bash

# Author: Andrew Howard

MODEL=501

echo "Welcome!  Let's configure a pix501!"
echo "(Not a 501?  Probably don't want this guide)"
echo ""

echo -e "I need information about the \033[1mSERVER\033[0m"
read -p "Customer's domain (rootmypc.net): " DOMAIN
read -p "Primary server (server1): " HOSTNAME
read -p "Allocated netblock (64.38.17.0/29): " ALLOCATION
read -p "Open TCP ports? (21,25,80,443): " TCPORTS
read -p "Open UDP ports? (20,21,53,161): " UDPORTS
echo ""
echo -e "Now some info about the \033[1mFIREWALL\033[0m"
read -p "Pix public netblock (64.38.17.120/30): " PIXIP
read -p "Pix password (abc@123): " PASS

CIDR=`echo $PIXIP | cut -d/ -f2`
if [[ $CIDR -ne 30 ]]; then
  echo "WTF.  Give the pix a /30 and then we'll talk."
  exit 0
fi
CIDR=`echo $ALLOCATION | cut -d/ -f2`
NUMIPS=`echo "2^(32-$CIDR)-3" | bc`
BASE=`echo $ALLOCATION | cut -d/ -f1 | cut -d. -f4`
EXTC=`echo $ALLOCATION | cut -d. -f1-3`.
INTC=10.`echo "$RANDOM % 255" | bc`.`echo $EXTC | cut -d. -f3`.

echo ""
echo -e "\033[1mPrepare thyself for an initial pix501 config\033[0m"
echo -e "\033[1m==================================================\033[0m"
echo "en"
echo "config t"
echo "interface ethernet0 auto"
echo "interface ethernet1 100full"
echo "nameif ethernet0 outside security0"
echo "nameif ethernet1 inside security100"
echo "enable password $PASS"
echo "password $PASS"
echo "hostname pix$MODEL"
echo "domain-name $DOMAIN"

echo "names"
for x in `seq 1 $NUMIPS`; do
  echo "name $INTC$(($BASE+1+$x)) $HOSTNAME.int$x"
  echo "name $EXTC$(($BASE+1+$x)) $HOSTNAME.ext$x"
done

echo "object-group network FS_STAFF"
WHITELIST=`curl http://SERVER/fsofficesubnets.txt 2> /dev/null`
for x in $WHITELIST; do
  CIDR=`echo $x | sed s/^.*"\/"//`
  IPADDR=`echo $x | sed s/"\/$CIDR"//`
  NETMASK=255.255.255.`echo "256-2^(32-$CIDR)" | bc`
  echo "network-object $IPADDR $NETMASK"
done
echo "exit"

HOSTGROUP=`echo $HOSTNAME | tr a-z A-Z`

echo "object-group service ${HOSTGROUP}_TCP tcp"
for x in `echo $TCPORTS | sed s/,/"\n"/g`; do
  echo "port-object eq $x"
done
echo "exit"

echo "object-group service ${HOSTGROUP}_UDP udp"
for x in `echo $UDPORTS | sed s/,/"\n"/g`; do
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

echo "no dhcpd address 192.168.1.2-192.168.1.33 inside"
echo "no dhcpd lease 3600"
echo "no dhcpd ping_timeout 750"
echo "no dhcpd auto_config outside"
echo "no dhcpd enable inside"

PIX4=`echo $PIXIP | sed s/^".*\..*\..*\."// | sed s/"\/30"//`
PIXC=`echo $PIXIP | sed s/$PIX4"\/30"//`
echo "ip address outside $PIXC$(($PIX4+2)) 255.255.255.252"
echo "ip address inside ${INTC}1 255.255.255.0"

echo "ip audit info action alarm"
echo "ip audit attack action alarm"
for x in $WHITELIST; do
  CIDR=`echo $x | sed s/^.*"\/"//`
  IPADDR=`echo $x | sed s/"\/$CIDR"//`
  NETMASK=255.255.255.`echo "256-2^(32-$CIDR)" | bc`
  echo "pdm location $IPADDR $NETMASK outside"
done
echo "pdm location ${INTC}0 255.255.255.0 inside"
echo "pdm history enable"
echo "arp timeout 14400"
echo "nat (inside) 1 0.0.0.0 0.0.0.0 0 0"

for x in `seq 1 $NUMIPS`; do
  echo "static (inside,outside) $HOSTNAME.ext$x $HOSTNAME.int$x netmask 255.255.255.255 0 0"
done

echo "access-group outside_access_in in interface outside"

echo "route outside 0.0.0.0 0.0.0.0 $PIXC$((PIX4+1)) 1"

echo "http server enable"
for x in $WHITELIST; do
  CIDR=`echo $x | sed s/^.*"\/"//`
  IPADDR=`echo $x | sed s/"\/$CIDR"//`
  NETMASK=255.255.255.`echo "256-2^(32-$CIDR)" | bc`
  echo "http $IPADDR $NETMASK outside"
done
echo "http ${INTC}0 255.255.255.0 inside"

for x in $WHITELIST; do
  CIDR=`echo $x | sed s/^.*"\/"//`
  IPADDR=`echo $x | sed s/"\/$CIDR"//`
  NETMASK=255.255.255.`echo "256-2^(32-$CIDR)" | bc`
  echo "ssh $IPADDR $NETMASK outside"
done
echo "ssh ${INTC}0 255.255.255.0 inside"

echo "ca zeroize rsa"
echo "ca generate rsa key 1024"
echo "ca save all"

echo "write mem"
