#!/bin/bash
PATH=/root/scripts:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/nagios/libexec
# Author: Andrew Howard


####################################################
##  Backup the contents of /usr/local/nagios/etc  ##
####################################################

# Ensure directory structure exists for backup storage
mkdir -p /home/nagios/backup/{,config/{,hourly,daily,weekly,monthly},system/{,daily,weekly,monthly}}

# Change into the proper directory
cd /usr/local/nagios

# Set some variables, to use for naming backup files
DATE=`date +%Y-%m-%d`
HOUR=`date +%H`

# Keep 24 hourly backups
# Runs every time the script executes (hourly)
echo "Running hourly backup of nagios configuration"
tar -czf /home/nagios/backup/config/hourly/nagios.etc.$DATE.$HOUR.tgz --exclude etc/monitoring/slaves etc
tmpwatch -m 24 /home/nagios/backup/config/hourly

# Keep 7 daily backups
# Runs at 1:XX am
if [ $HOUR -eq 01 ]; then
  echo "Running daily backup of nagios configuration"
  cp /home/nagios/backup/config/hourly/nagios.etc.$DATE.$HOUR.tgz /home/nagios/backup/config/daily/nagios.etc.$DATE.tgz
  tmpwatch -m 168 /home/nagios/backup/config/daily

  # Keep 8 weekly backups
  # Runs at 1:XX am on Saturdays
  if [ `date +%u` -eq 6 ]; then
    echo "Running weekly backup of nagios configuration"
    cp /home/nagios/backup/config/daily/nagios.etc.$DATE.tgz /home/nagios/backup/config/weekly/nagios.etc.$DATE.tgz
    tmpwatch -m 1344 /home/nagios/backup/config/weekly

    # Keep 6 monthly backups
    # Runs at 1:XX am on the first Saturday of the month
    if [ `date +%d` -le 7 ]; then
      echo "Running monthly backup of nagios configuration"
      cp /home/nagios/backup/config/weekly/nagios.etc.$DATE.tgz /home/nagios/backup/config/monthly/nagios.etc.$DATE.tgz
      tmpwatch -m 4320 /home/nagios/backup/config/monthly
    fi
  fi
fi


###################################################
##              Backup all of Atma               ##
###################################################

# Function replicates important files/dirs to a mirror of / in /home/nagios/master/,
#  then tars the whole directory structure and dumps output to STDOUT
systemdump()
{
  mkdir -p /home/nagios/master/{,usr/local,etc/{,init.d,sysconfig,xinetd.d,cron.d},home/{,nagios,cacti},var/spool}

  rsync -plar --delete --exclude etc/monitoring/slaves --exclude etc/monitoring/dynamic /usr/local/nagios /home/nagios/master/usr/local/
  rsync -plar --delete /etc/cron.d/cacti /home/nagios/master/etc/cron.d/
  rsync -plar --delete /etc/exports /home/nagios/master/etc/
  rsync -plar --delete /etc/hosts /home/nagios/master/etc/
  rsync -plar --delete /etc/httpd /home/nagios/master/etc/
  rsync -plar --delete /etc/init.d/nagios /home/nagios/master/etc/init.d/
  rsync -plar --delete /etc/init.d/nsca /home/nagios/master/etc/init.d/
  rsync -plar --delete /etc/ntp.conf /home/nagios/master/etc/
  rsync -plar --delete /etc/services /home/nagios/master/etc/
  rsync -plar --delete /etc/sudoers /home/nagios/master/etc/
  rsync -plar --delete /etc/sysconfig/iptables /home/nagios/master/etc/sysconfig/
  rsync -plar --delete /etc/sysctl.conf /home/nagios/master/etc/
  rsync -plar --delete /etc/xinetd.d/nsca /home/nagios/master/etc/xinetd.d/
  rsync -plar --delete /etc/yum.repos.d /home/nagios/master/etc/
  rsync -plar --delete /home/nagios/.ssh /home/nagios/master/home/nagios/
  rsync -plar --delete /root /home/nagios/master/
  rsync -plar --delete /usr/share/ssl /home/nagios/master/usr/share/
  rsync -plar --delete /var/spool/cron /home/nagios/master/var/spool/
  rsync -plar --delete /var/www /home/nagios/master/var/

  for x in /usr/local/nagios/etc/monitoring/slaves/*; do
    mkdir -p /home/nagios/master$x;
  done
  mkdir -p /home/nagios/master/usr/local/nagios/etc/monitoring/dynamic

  mysqldump cacti > /home/nagios/master/home/cacti/cacti.sql

  CWD=`pwd`
  cd /home/nagios/master
  tar -cz *
  cd $CWD
  rm -rf /home/nagios/master
} # END systemdump()

# Keep 7 daily backups
# Runs at 1:XX am
if [ $HOUR -eq 01 ]; then
  echo "Running daily system backup"
  cd /etc
  tar -czf /home/nagios/backup/system/atma.yum.repos.d.tgz yum.repos.d
  systemdump > /home/nagios/backup/system/daily/master.$DATE.tgz
  tmpwatch -m 168 /home/nagios/backup/system/daily

  # Keep 8 weekly backups
  # Runs at 1:XX am on Saturdays
  if [ `date +%u` -eq 6 ]; then
    echo "Running weekly system backup"
    cp /home/nagios/backup/system/daily/master.$DATE.tgz /home/nagios/backup/system/weekly/master.$DATE.tgz
    tmpwatch -m 1344 /home/nagios/backup/system/weekly

    # Keep 6 monthly backups
    # Runs at 1:XX am on the first Saturday of the month
    if [ `date +%d` -le 7 ]; then
      echo "Running monthly system backup"
      cp /home/nagios/backup/system/weekly/master.$DATE.tgz /home/nagios/backup/system/monthly/master.$DATE.tgz
      tmpwatch -m 4320 /home/nagios/backup/system/monthly
    fi
  fi
fi


###################################################
##       Sync backups to the nagios slaves       ##
###################################################

echo "Syncing backups against the slaves"
cd /usr/local/nagios/etc/monitoring/slaves
for x in *; do
  echo "Rsyncing to $x"
  rsync -plar --delete /home/nagios/backup/ $x:/home/nagios/backup/
done

echo "All backup processes complete"

exit

