#!/bin/bash

# Author: Andrew Howard

echo
echo "This system is exclusively for resetting the meta data on cloud servers"
echo "  that have failed post-build automation scripts.  Before proceeding,"
echo "  you should ensure you're manually performed all the steps that would"
echo "  normally be performed by automation."
echo "For linux, that would be installing driveclient and the cloud monitoring"
echo "  agent.  For windows, I couldn't tell you.  Sorry."
echo "For issues with this tool, please contact Andrew Howard."
echo

read -p "What DC? [DFW, ORD, LON, AUS] " DC
read -p "What's the DDI (cloud account #) of the account? " DDI
read -p "What's this account's API username? " APIUSER
read -p "What's this account's API key (not token)? " APIKEY
read -p "What's the server ID? " SERVERID

supernova $DC --os-username $APIUSER --os-password $APIKEY --os-tenant-name $DDI show $SERVERID
echo
echo "Please verify the information above is for the server we're resetting."
read -p "Would you like to proceed? [y/N] " CONFIRM

if [[ "$CONFIRM" =~ ^(y|Y)$ ]]; then
  supernova $DC --os-username $APIUSER --os-password $APIKEY --os-tenant-name $DDI meta $SERVERID set rax_service_level_automation="Complete"
  echo
  supernova $DC --os-username $APIUSER --os-password $APIKEY --os-tenant-name $DDI show $SERVERID
  echo
  echo "The status has been updated.  New information is displayed above."
else
  echo "Aborted.  Nothing has been changed."
fi

read -p "Hit return to exit..." BLAH
exit 0

