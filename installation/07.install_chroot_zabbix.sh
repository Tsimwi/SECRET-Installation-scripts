#!/bin/bash
# Zabbix agent installation
# Install Zabbix agent inside the chroot (must then be allowed inside ltsp.conf)

# Enter chroot
schroot -c bionic -u root

# Install Zabbix repository (the link may change according to the chosen database and web server)
# https://www.zabbix.com/download?zabbix=5.0&os_distribution=ubuntu&os_version=20.04_focal&db=postgresql&ws=apache
wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+bionic_all.deb
dpkg -i zabbix-release_5.0-1+bionic_all.deb
apt update
apt install zabbix-agent -y
systemctl enable zabbix-agent
rm zabbix-release_5.0-1+bionic_all.deb

# Allow zabbix to run admin commands
cat > /etc/sudoers.d/zabbix << 'EOF'
zabbix  ALL=(ALL:ALL) NOPASSWD: /bin/ps
zabbix  ALL=(ALL:ALL) NOPASSWD: /sbin/iptables-save
EOF

# Then create custom user parameters
cat > /etc/zabbix/zabbix_agentd.d/zabbix_ltsp.conf << 'EOF'
HostMetadataItem=system.uname
UserParameter=system.users.name,users
UserParameter=proc.list,sudo ps aux
UserParameter=net.iptables.cksum,sudo iptables-save | grep -v '^[#:]' | sha256sum
UserParameter=dconf.proxy.cksum,dconf dump /system/proxy/ | sha256sum
EOF

# Zabbix monitoring : logkeys
touch /var/log/logkeys.log
chown root:zabbix /var/log/logkeys.log
chmod o-r /var/log/logkeys.log

# Leave chroot
exit