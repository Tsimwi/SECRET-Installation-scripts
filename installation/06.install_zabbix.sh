#!/bin/bash
# Zabbix server installation

# 1. PostgreSQL installation
# Create the file repository configuration:
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Import the repository signing key:
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Install PostgreSQL :
sudo apt update
sudo apt install postgresql -y

# Install Zabbix dependencies (Apache, PHP, PHP extensions, PCRE library, libevent, libpthread, zlib)
sudo apt install apache2 php libapache2-mod-php php-xml php-gd php-bcmath php-mbstring php-pgsql libpcre3 libevent-2.1-6 libpthread-workqueue0 zlibc fping openipmi snmpd snmp -y

# Install Zabbix repository (the link may change according to the chosen database and web server)
# https://www.zabbix.com/download?zabbix=5.0&os_distribution=ubuntu&os_version=20.04_focal&db=postgresql&ws=apache
wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+bionic_all.deb
sudo dpkg -i zabbix-release_5.0-1+bionic_all.deb
rm zabbix-release_5.0-1+bionic_all.deb
sudo apt update

# Install Zabbix server, frontend, agent
sudo apt install zabbix-server-pgsql zabbix-frontend-php php7.2-pgsql zabbix-apache-conf zabbix-agent -y
# Create initial database
sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix zabbix
# Import initial schema and data
zcat /usr/share/doc/zabbix-server-pgsql*/create.sql.gz | sudo -u zabbix psql zabbix

# Allow zabbix user to read syslog
sudo setfacl -m u:zabbix:r /var/log/syslog

# Create a custom script to allow Zabbix to discover students system proxy settings
sudo tee -a /usr/lib/zabbix/externalscripts/dconf_discovery.sh > /dev/null << 'EOF'
#!/bin/bash
for user in $(sudo find /home/ -maxdepth 1 -regextype egrep -regex '/home/.+_.+' 2> /dev/null | cut -d '/' -f3); do
        checksum=$(sudo -Hu ${user} dconf dump /system/proxy/ | sha256sum)
        echo ${user} ${checksum} | tee /home/${user}/.monitoring/proxy_settings
done
EOF
sudo chmod o+x /usr/lib/zabbix/externalscripts/dconf_discovery.sh
# Create a custom script to allow Zabbix to update the state of students system proxy settings
sudo tee /usr/lib/zabbix/externalscripts/dconf_update.sh > /dev/null << 'EOF'
#!/bin/bash
for user in $(sudo find /home/ -maxdepth 1 -regextype egrep -regex '/home/.+_.+' 2> /dev/null | cut -d '/' -f3); do
        checksum=$(sudo -Hu ${user} dconf dump /system/proxy/ | sha256sum)
        echo ${user} ${checksum} > /home/${user}/.monitoring/proxy_settings
done
EOF
sudo chmod o+x /usr/lib/zabbix/externalscripts/dconf_update.sh

# Allow zabbix to run admin commands
sudo tee /etc/sudoers.d/zabbix > /dev/null << 'EOF'
zabbix  ALL=(ALL:ALL) NOPASSWD: /usr/bin/find
zabbix  ALL=(ALL:ALL) NOPASSWD: /usr/bin/dconf
EOF

