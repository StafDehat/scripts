#!/bin/bash

(
for x in `cat /etc/passwd | awk -F : '$3 > 500 {print $1}'`; do
  USERNAME=$x
  USERID=`grep "^$USERNAME:" /etc/passwd | cut -d: -f3`
  GROUPS=`groups $USERNAME | cut -d: -f2-`
  ACTIVE=`grep "^$USERNAME:" /etc/shadow | grep -v "^$USERNAME:\!" | grep -v "^$USERNAME::" | wc -l`
  LOGIN=`lastlog -u $USERNAME | sed 's/\s\s*/ /g' | tail -n +2 | cut -d\  -f4-`
  HOMEDIR=`grep "^$USERNAME:" /etc/passwd | cut -d: -f6`
  CREATION=`stat /home/$USERNAME/.bash_logout | grep Modify: | cut -d\  -f2-`
  echo "$USERID | $USERNAME | $GROUPS | $ACTIVE | $LOGIN | $CREATION"
done
echo "User ID | Username | Groups | Active? | Last login | Created"
) | column -t -s \|

