#!/bin/bash

# Author: Andrew Howard

service minecraft command "/effect $1 1 300 $2" # speed
service minecraft command "/effect $1 3 300 $2" # haste digging
service minecraft command "/effect $1 5 300 $2" # strength
service minecraft command "/effect $1 8 300 1" # jump
service minecraft command "/effect $1 10 300 $2" # regen
service minecraft command "/effect $1 11 300 $2" # damage resist
service minecraft command "/effect $1 12 300 $2" # fire resist
service minecraft command "/effect $1 13 300 $2" # water breathing
#service minecraft command "/effect $1 16 300 $2" # night vision

