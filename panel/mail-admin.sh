#!/bin/bash

VIRTUALDOMAINS=/etc/postfix/virtualdomains
FORWARDERS=/etc/postfix/forwarders
PASSWORDS=/etc/dovecot/virtual.passwd
MAILBOXES=/etc/postfix/virtualmailboxes
MAILROOT=/home/mail
POSTMAP=/usr/sbin/postmap

echo
echo "Options:"
echo "  1. Create new mail account"
echo "  2. Create new mail forwarder"
echo "  3. Delete mail account"
echo "  4. Delete mail forwarder"
echo "  5. Change mail account password"
echo "  6. Change domain delivery options"
echo "  7. List domains for which this server accepts mail locally"
echo "  8. List mail accounts for a domain"
echo "  9. List forwarders for a domain"
echo
read -p "Enter option [1-9], or Q to quit: " OPT

case $OPT in
  #
  #  Create a new account - warn if domain's not local
  1) echo
     read -p "Email account to create: " ACCOUNT
     echo 'Note: Password can not contain these characters: ! $ ` \ "'
     read -p "Password for new account: " PASSWORD
     echo
     DOMAIN=`echo $ACCOUNT | cut -d@ -f2`
     USER=`echo $ACCOUNT | cut -d@ -f1`
     if [ `egrep -c "^$DOMAIN\s" $VIRTUALDOMAINS` -lt 1 ]; then
       echo "Warning: Mail to $DOMAIN is currently delivered remotely."
     fi
     if [ `egrep -c "^$ACCOUNT\s" $FORWARDERS` -gt 0 ]; then
       sed -i "/^$ACCOUNT\s/s/\s*$/,$ACCOUNT/" $FORWARDERS
     fi
     mkdir -p $MAILROOT/$DOMAIN/$USER/Maildir
     chown -R vmail.vmail $MAILROOT/$DOMAIN
     echo "$ACCOUNT $DOMAIN/$USER/Maildir/" >> $MAILBOXES
     echo "$ACCOUNT:{plain}$PASSWORD" >> $PASSWORDS
     postmap $MAILBOXES
     postmap $FORWARDERS
     echo "User $ACCOUNT with password '$PASSWORD' was created successfully."
     ;;

  #
  #  Create a new forwarder.
  2) echo
     echo "Mail sent to 'relay address' is forwarded to 'target address'."
     read -p "Enter relay address:  " RELAY
     read -p "Enter target address: " TARGET
     echo
     DOMAIN=`echo $RELAY | cut -d@ -f2`
     if [ `egrep -c "^$DOMAIN\s" $VIRTUALDOMAINS` -lt 1 ]; then
       echo "Warning: Mail to $DOMAIN is currently delivered remotely."
     fi
     if [ "$TARGET" == "$RELAY" ]; then
       echo "Error: Can not forward an address to itself."
       echo "No changes applied."
     elif [ `egrep -c "^$RELAY\s" $FORWARDERS` -gt 0 ]; then
       if [ `egrep "^$RELAY\s" $FORWARDERS | egrep -c '(\s|,)'$TARGET'(,|$)'` -gt 0 ]; then
         echo "$RELAY is already being forwarded to $TARGET."
         echo "No changes applied."
       else
         sed -i "/^$RELAY\s/s/\s*$/,$TARGET/" $FORWARDERS
         echo "Forward created successfully."
       fi
     else
       if [ `egrep -c "^$RELAY\s" $MAILBOXES` -gt 0 ]; then
         echo "$RELAY $RELAY,$TARGET" >> $FORWARDERS
         echo "Forward created successfully."
       else
         echo "$RELAY $TARGET" >> $FORWARDERS
         echo "Forward created successfully."
       fi
     fi
     postmap $FORWARDERS
     ;;

  #
  #  Delete an account
  3) echo
     read -p "Email account to delete: " ACCOUNT
     echo
     if [ `egrep -c "^$ACCOUNT:" $PASSWORDS` -lt 1 ]; then
       echo "User $ACCOUNT does not exist.  No changes applied."
     else
       USER=`echo $ACCOUNT | cut -d@ -f1`
       DOMAIN=`echo $ACCOUNT | cut -d@ -f2`
       sed -i "/^$ACCOUNT\s/d" $MAILBOXES
       sed -i "/^$ACCOUNT:/d" $PASSWORDS
       postmap $MAILBOXES
       rm -rf $MAILROOT/$DOMAIN/$USER
       if [ `egrep -c "^$ACCOUNT\s" $FORWARDERS` -gt 0 ]; then
         RELAY=`egrep "^$ACCOUNT\s" /etc/postfix/forwarders | awk '{print $1}'`
         TARGETS=`egrep "^$ACCOUNT\s" /etc/postfix/forwarders | awk '{print $2}'`
         sed -i "/^$ACCOUNT\s/d" $FORWARDERS
         NEWTARGETS=$(for TARGET in `echo $TARGETS | sed 's/,/ /g'`; do
                        echo "$TARGET," | egrep -v "^$ACCOUNT,"
                      done)
         ( echo -n "$RELAY "
         for TARGET in $NEWTARGETS; do
           echo -n "$TARGET"
         done | sed 's/,\s*$//'
         echo ) >> $FORWARDERS
         postmap $FORWARDERS
       fi
       echo "User $ACCOUNT has been removed."
     fi
     ;;

  #
  #  Delete mail forwarder
  4) echo
     echo "Mail sent to 'relay address' is forwarded to 'target address'."
     read -p "Enter relay address: " RELAY
     echo
     TARGETS=`egrep "^$RELAY\s" $FORWARDERS | awk '{print $2}'`
     NUM=`echo $TARGETS | sed 's/,/\n/g' | egrep -v "^$RELAY$" | wc -l`
     if [ `egrep -c "^$RELAY\s" $FORWARDERS` -lt 1 ]; then
       echo "No forwarders configured for $RELAY."
       echo "No changes applied."
     elif [ $NUM -eq 1 ]; then 
       TARGET=`echo $TARGETS | sed 's/,/\n/g' | egrep -v "^$RELAY$"`
       echo "$RELAY currently forwarded to $TARGET."
       read -p "Delete? [Y/n]: " OPT
       echo
       if [ `echo $OPT | egrep -c '^n|N'` -gt 0 ]; then
         echo "No changes applied."
       else
         sed -i "/^$RELAY\s/d" $FORWARDERS
         echo "Deleted forward from $RELAY to $TARGET."
       fi
     else
       echo "$RELAY currently forwarded to the following addresses:"
       for TARGET in `echo $TARGETS | sed 's/,/\n/g' | egrep -v "^$RELAY$"`; do
         echo "$TARGET"
       done
       echo
       read -p "Enter target address: " TARGET
       echo
       sed -i "/^$RELAY\s/d" $FORWARDERS
       NEWTARGETS=$(for TEMP in `echo $TARGETS | sed 's/,/ /g'`; do
                      echo "$TEMP," | egrep -v "^$TARGET,"
                    done)
       ( echo -n "$RELAY "
       for TEMP in $NEWTARGETS; do
         echo -n "$TEMP"
       done | sed 's/,\s*$//'
       echo ) >> $FORWARDERS
       echo "Deleted forward from $RELAY to $TARGET."
     fi
     postmap $FORWARDERS
     ;;

  #
  #  Change an account password
  5) echo
     read -p "Enter account: " ACCOUNT
     echo
     if [ `egrep -c "^$ACCOUNT:" $PASSWORDS` -lt 1 ]; then
       echo "User $ACCOUNT does not exist.  No changes applied."
     else
       echo 'Note: Password can not contain these characters: ! $ ` \ "'
       read -p "Enter new password for $ACCOUNT: " PASSWORD
       sed -i "/^$ACCOUNT:/s/:.*$/:{plain}$PASSWORD/" $PASSWORDS
       echo
       echo "Password for $ACCOUNT changed to '$PASSWORD'."
     fi
     ;;

  #
  #  Toggle domain between local and remote delivery
  6) echo
     read -p "Domain to modify: " DOMAIN
     echo
     if [ `egrep -c "^$DOMAIN\\s" $VIRTUALDOMAINS` -lt 1 ]; then
       echo "Mail for $DOMAIN is currently being delivered remotely."
       read -p "Configure server to accept mail locally for $DOMAIN? [y/N]: " OPT
       echo
       if [ `echo $OPT | egrep -c '^y|Y'` -gt 0 ]; then
         echo "$DOMAIN placeholder" >> $VIRTUALDOMAINS
         postmap $VIRTUALDOMAINS
         echo "Server will now deliver mail for $DOMAIN locally."
       else
         echo "No changes applied."
       fi
     else
       echo "Mail for $DOMAIN is currently being accepted locally."
       read -p "Configure server to deliver mail remotely for $DOMAIN? [y/N]: " OPT
       echo
       if [ `echo $OPT | egrep -c '^y|Y'` -gt 0 ]; then
         sed -i "/^$DOMAIN\\s/d" $VIRTUALDOMAINS
         postmap $VIRTUALDOMAINS
         echo "Server will now deliver mail for $DOMAIN remotely."
       else
         echo "No changes applied."
       fi
     fi
     ;;

  #
  #  List domains for which this server accepts mail locally
  7) echo
     cat $VIRTUALDOMAINS | awk '{print $1}' | sort
     ;;

  #
  #  List mail accounts for a domain
  8) echo
     read -p "Enter domain: " DOMAIN
     echo
     grep "@$DOMAIN:" $PASSWORDS | cut -d: -f1 | sort
     ;;

  #
  #  List forwarders for a domain
  9) echo
     read -p "Enter domain: " DOMAIN
     echo
     egrep '^.*'$DOMAIN'\s\s*.*@' $FORWARDERS | while read LINE; do
       SRC=`echo $LINE | cut -d\  -f1`
       DSTS=`echo $LINE | cut -d\  -f2 | sed 's/,/ /g'`
       for DST in $DSTS; do
         if [ $SRC != $DST ]; then
           echo -e "$SRC -> $DST"
         fi
       done
     done | sort | column -t
     ;;

  #
  #  Catch-all.  Exit.
  *) exit 1
     ;;
esac

