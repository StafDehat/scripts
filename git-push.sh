#!/bin/bash

cd /home/ahoward/scripts
git add -A
git commit
git pull

git push
if [ $? -ne 0 ]; then
  git status
fi
