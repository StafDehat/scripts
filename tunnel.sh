#!/bin/bash

read -p "What server are you trying to reach? " IP
read -p "What user will you login as? " USER
read -p "What port do you want to reach remotely? " REMPORT
read -p "What port will you connect to locally? " LOCPORT

echo "Run this command:"
echo "  ssh $USER@$IP -L $LOCPORT:localhost:$REMPORT"
echo 

