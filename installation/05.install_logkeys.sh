#!/bin/bash
# Logkeys installation

# Install required packages
apt install autotools-dev autoconf make automake g++ -y

# You can either git clone or download the zip file from the Github repository
cd /opt
wget https://github.com/kernc/logkeys/archive/master.zip
unzip master.zip
rm master.zip
cd logkeys-master
# generate files for build
./autogen.sh
# keeps the root and src dirs clean 
cd build
../configure
make
make install
cd

# Configure Logkeys to run after user login and set shell environement variables
mv /etc/gdm3/PostLogin/Default.sample /etc/gdm3/PostLogin/Default
cat >> /etc/gdm3/PostLogin/Default << 'EOF'
# Start logkeys keylogger at login
/usr/local/bin/logkeys --start --keymap=/opt/logkeys-master/keymaps/fr_CH.map --output /var/log/logkeys.log

# Allow zabbix to read /var/log/syslog
# Must be done here because syslog does not exist inside the chroot
setfacl -m u:zabbix:r /var/log/syslog

# Set shell environement variables
# Must be done here otherwise they are applied inside the chroot
export http_proxy=192.168.67.1:8080
export https_proxy=192.168.67.1:8080
export no_proxy=localhost,127.0.0.1
EOF

# Configure Logkeys to stop before user logout
cat > /etc/gdm3/PostSession/Default << 'EOF'
#!/bin/sh

# Stop logkeys keylogger at logout
/usr/local/bin/logkeys --kill
exit 0
EOF
