#!/bin/bash


echo "git stash"
while read LINE; do
  echo "git filter-branch --force --index-filter \"git rm --cached --ignore-unmatch $LINE\" --prune-empty --tag-name-filter cat -- --all"
done
echo "git push origin master --force"
echo "git stash apply"
