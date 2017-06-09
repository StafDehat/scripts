#!/bin/bash
# Author: Andrew Howard

DATE=$( date +%F-%T )
SNET_ADDR=$( simpana status | grep 'Client Hostname' | awk '{print $NF}' )
INTERFACES=( $( ip link show | grep UP | awk '{print $2}' | sed 's/:\s*$//' ) )
for INT in ${INTERFACES[@]}; do
  grep -q "${SNET_ADDR}" <( ip addr show dev "${INT}" ) \
    && SNET_INT="${INT}" && break
done

declare -a NETWORKS
NETWORKS=( $( ip route show dev "${SNET_INT}" |
                grep ' via ' | grep -Po '(\d+\.){3}\d+(/\d+)?' |
                sort -u |
                sed '/\.[0-9]\+$/d' ) )

DESC=""
for NET in ${NETWORKS[@]}; do
  DESC+="and not net ${NET} "
done
DESC="${DESC/and /}"

tcpdump -w /home/rack/"${DATE}".pcap -qni "${SNET_INT}" proto \( TCP or UDP \) and "${DESC}"
