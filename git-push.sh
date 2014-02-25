#!/bin/bash

cd /home/ahoward/scripts
find . | xargs git add
git commit
git push

