#!/usr/bin/env bash

function usage {
  echo "Usage: $0 [-h] [-H server-ip] [-p server-port]"
  echo "  -h  Display this help"
  echo "  -H  The IP/hostname of server to test (default localhost)"
  echo "  -T  The port on the server to test (default 443)"
}

# OpenSSL requires the port number.
SERVER=localhost
PORT=443
DELAY=0
ciphers=$(openssl ciphers 'ALL:eNULL' | sed -e 's/:/ /g')

# Handle command-line arguments
while getopts ":H:p:h" ARG
do
  case $ARG in
    H  ) SERVER=$OPTARG
         ;;
    p  ) PORT=$OPTARG
         ;;
    # Help menu
    h  ) usage
         exit 1;;
    # Catch-all, error message
    *  ) echo "Unknown argument: $OPTARG"
         usage
         exit 1;;
  esac
done

echo Obtaining cipher list from $(openssl version).
echo "Testing ciphers supported by server at $SERVER:$PORT"

for cipher in ${ciphers[@]}
do
echo -n Testing $cipher...
result=$(echo -n | openssl s_client -cipher "$cipher" -connect $SERVER:$PORT 2>&1)
if [[ "$result" =~ "Cipher is " ]] ; then
  echo YES
else
  if [[ "$result" =~ ":error:" ]] ; then
    error=$(echo -n $result | cut -d':' -f6)
    echo NO \($error\)
  else
    echo UNKNOWN RESPONSE
    echo $result
  fi
fi
sleep $DELAY
done

