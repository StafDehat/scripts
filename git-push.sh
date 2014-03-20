#!/bin/bash

cd /home/ahoward/scripts
#find . | xargs git add -A
git add -A
git pull
git commit
git push

