#!/bin/bash

# Author: Andrew Howard

GETTCP=0
GETUDP=0
while getopts ":tuh" arg
do
  case $arg in
    # List suggested TCP ports
    t  ) GETTCP=1;;
    # List suggested UDP ports
    u  ) GETUDP=1;;
    # Help menu
    h  ) echo "Usage: $0 [-h] [-t|-u]"
         echo "  -t  Print only suggested TCP ports, in comma-separated format"
         echo "  -u  Print only suggested UDP ports, in comma-separated format"
         echo "  -h  Display this help menu"
         exit 1;;
    # Catch-all, error message
    *  ) echo "Unknown argument: $arg"
         exit 1;;
  esac
done


FS_PORTS=$(wget -o /dev/null -O - SERVER/csf/fs-ports)

if [ $GETTCP -eq 1 ]; then
  # Determine ports on which a service is listening
  LISTEN_TCP=$(netstat -an | grep LISTEN | grep -v LISTENING| awk '{print $4}' | sed s/.*:// | sort -nu | xargs echo -n)
  # Find conjunct of FS_PORTS and LISTEN_TCP
  OPEN_TCP=$(echo "$LISTEN_TCP $FS_PORTS" | sed 's/\s\s*/\n/g' | sort -n | uniq -d)
  # Explicitly open the SSH port
  OPEN_TCP=$(echo $OPEN_TCP `grep -Ei '^port' /etc/ssh/sshd_config | awk '{print $2}'`)
  OPEN_TCP=$(echo $OPEN_TCP | sed 's/\s\s*/\n/g' | sort -nu | xargs echo -n | sed 's/\s\s*/,/g')
  echo $OPEN_TCP;
elif [ $GETUDP -eq 1 ]; then
  # Determine ports on which a service is listening
  LISTEN_UDP=$(netstat -an | grep udp | awk '{print $4}' | awk -F : '{print $2}' | sort -nu | grep -vE '^\s*$')
  # Find conjunct of FS_PORTS and LISTEN_UDP
  OPEN_UDP=$(echo "$LISTEN_UDP $FS_PORTS" | sed 's/\s\s*/\n/g' | sort -n | uniq -d | xargs echo -n | sed 's/\s\s*/,/g')
  echo $OPEN_UDP
else
  # Determine ports on which a service is listening
  LISTEN_TCP=$(netstat -an | grep LISTEN | grep -v LISTENING| awk '{print $4}' | sed s/.*:// | sort -nu | xargs echo -n)
  # Find conjunct of FS_PORTS and LISTEN_TCP
  OPEN_TCP=$(echo "$LISTEN_TCP $FS_PORTS" | sed 's/\s\s*/\n/g' | sort -n | uniq -d)
  # Explicitly open the SSH port
  OPEN_TCP=$(echo $OPEN_TCP `grep -Ei '^port' /etc/ssh/sshd_config | awk '{print $2}'`)
  OPEN_TCP=$(echo $OPEN_TCP | sed 's/\s\s*/\n/g' | sort -nu | xargs echo -n | sed 's/\s\s*/,/g')

  # Determine ports on which a service is listening
  LISTEN_UDP=$(netstat -an | grep udp | awk '{print $4}' | awk -F : '{print $2}' | sort -nu | grep -vE '^\s*$')
  # Find conjunct of FS_PORTS and LISTEN_UDP
  OPEN_UDP=$(echo "$LISTEN_UDP $FS_PORTS" | sed 's/\s\s*/\n/g' | sort -n | uniq -d | xargs echo -n | sed 's/\s\s*/,/g')

  echo "TCP: $OPEN_TCP"
  echo "UDP: $OPEN_UDP"
fi

