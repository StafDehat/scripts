#!/bin/bash

cd /home/ahoward/scripts
git pull
find . | xargs git add
git commit
git push

