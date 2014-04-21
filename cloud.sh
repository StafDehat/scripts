#!/bin/bash

# Author: Andrew Howard

source /home/ahoward/.tier2-creds

function ng {
  echo "You'll need your SSO password"
  ssh $USERNAME@bastion1.ohthree.com
}
function h {
ssh h$1.slicehost.net -i $SSHKEY -p 22
}
function qb {
ssh qb$1.slicehost.com -i $SSHKEY -p 314
}
function db {
ssh db$1.slicehost.com -i $SSHKEY -p 314
}
function app {
ssh app$1.slicehost.com -i $SSHKEY -p 314
}
function iback {
if [ "$1" -gt "2" ] && [ "$1" -lt "13" ] ; then
ssh iback$1-dfw1.slicehost.com -i $SSHKEY -p 314
fi
if [ "$1" -gt "15" ] && [ "$1" -lt "27" ] ; then
ssh iback$1-$2-dfw1.slicehost.com -i $SSHKEY -p 314
fi
if [ "$1" -gt "26" ] && [ "$1" -lt "100" ] ; then
ssh iback$1-$2-ord1.slicehost.com -i $SSHKEY -p 314
fi
if [ "$1" -gt "99" ] && [ "$1" -lt "200" ] ; then
ssh iback$1-$2-lon.slicehost.com -i $SSHKEY -p 314
fi
if [ "$1" -gt "199" ] && [ "$1" -lt "400" ] ; then
ssh iback$1-stla.slicehost.com -i $SSHKEY -p 314
fi
if [ "$1" -gt "399" ] && [ "$1" -lt "500" ] ; then
ssh iback$1-stlb.slicehost.com -i $SSHKEY -p 314
fi
if [ "$1" -gt "499" ] ; then
ssh iback$1-$2-dfw2.slicehost.com -i $SSHKEY -p 314
fi
}
function cloudlogs {
  ssh $USERNAME@syslogsearch.support.ohthree.com
}
