#!/bin/bash

# Author: Andrew Howard

# Only tested on CentOS-6 

# Pre-req packages
yum -y install git
cd /
git clone https://github.com/StafDehat/scripts
cd
ln -s /scripts/prompt.sh /etc/profile.d/
yum -y install screen

# Lockdown SSH a bit
sed -i 's/^\s*#\{0,1\}\s*Port\s.*$/Port 129/' /etc/ssh/sshd_config
sed -i 's/^\s*#\{0,1\}\s*PermitRootLogin\s.*$/PermitRootLogin no/' /etc/ssh/sshd_config 
service sshd restart
service iptables stop
chkconfig iptables off
service postfix stop
chkconfig postfix off

# Add crypto user
sed -i '/^Defaults\s*requiretty/s/^/#/' /etc/sudoers
adduser crypto
echo "crypto ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
rm -rf /home/crypto/.ssh
sudo -u crypto ssh-keygen -t dsa -N "" -f /home/crypto/.ssh/id_dsa
cat <<EOF >/home/crypto/.ssh/authorized_keys
ssh-dss AAAAB3NzaC1kc3MAAACBAPVtD84oTasXaU0x9mROiRbEUw7kRnXbo3yqz9ypqJtOPC6vU6GsRpKNyzXnsmJcqVzFhcosi6m1ebBbTOffc8B5FdkwiEEh43XKw8c8M+Myt128oP18qAQLoJfdReFTdFKE3vFKZ0aZn6Rba+ucgc3Na0osNUrz10IOws7okMpPAAAAFQDbvYy3oc0L+XFa5URvch4e3PLt3wAAAIB2w01mGHkLwp/x9xrREcRMYmin46oXVVR2KkJTo8QvXyVQwefA2h9NTp3ihtPA9vBpSmPvnb+EgnC+uKCXJqazfZM2b5JjSvSx7gWsQtYLHyEPCX9hNksEEFl2Rbykn/zN0gKMFt6KfG8o4lkphBhqHVU72xP/p1EoQ3iuky+/GQAAAIAmLd4rXmCYoSJA2EGls54sv47La+0aK9GibK2HeTFl1GL5M+2TtDaau5oVdm4+e7U1k6KOeRi7vKEXIPkdLnJHvXfyChElEDJ1ZhBqEFXmsOCjlEnBd+TAhJ6CtOeSUxQtPsstv1BpG378eJ5w53zpxfTP8M4Zz/eEJ5SWC7WdEg== ahoward@phoenix
EOF
chmod 600 /home/crypto/.ssh/authorized_keys

# Populate the files
cd /home/crypto
wget http://dev.rootmypc.net/crypto.tgz
tar -xzf crypto.tgz
mv miner /etc/init.d/
chkconfig --add miner
chkconfig miner off

# Get things started
echo '*/5 * * * * /home/crypto/monitor.sh 2>&1 >/dev/null' > /var/spool/cron/crypto
chown crypto:crypto /var/spool/cron/crypto
chown -R crypto:crypto /home/crypto
service crond restart

