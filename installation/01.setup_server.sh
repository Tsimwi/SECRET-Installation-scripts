#!/bin/bash
# Server configuration & packages installation
sudo apt update && sudo apt upgrade -y
# In case timezone is not correctly set
sudo timedatectl set-timezone Europe/Zurich

# Add LTSP repository
sudo add-apt-repository ppa:ltsp -y
sudo apt update

# Install required packages to run an LTSP server and a chrooted environement :
# - LTSP, dnsmasq, ssh and nfs servers, squashfs and network tools
sudo apt install --install-recommends ltsp ltsp-binaries dnsmasq nfs-kernel-server openssh-server squashfs-tools ethtool net-tools -y
sudo apt install debootstrap schroot pwgen -y

# *EDIT*
# Configure clients' side network interface.
# Replace interface name (eno1) and gateway4 with wanted values
sudo tee /etc/netplan/02_config_ltsp.yaml > /dev/null << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:
      addresses:
        - 192.168.67.1/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [192.168.67.1]
EOF
# *EDIT*
# Replace interface name (eno2) with wanted value
sudo tee /etc/netplan/03_config_lan.yaml > /dev/null << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eno2:
      dhcp4: true
EOF
sudo netplan apply

# Generate the dnsmasq configuration file for a "2 NIC" architecture
sudo ltsp dnsmasq --proxy-dhcp=0

# *EDIT*
# Apply iptables rules. Replace `-o interface` (ens38) in the first rule with wanted interface (the one facing ltsp clients)
# Port 5432 is for postgresql, 10051 for zabbix
sudo iptables -A OUTPUT -p tcp -d 127.0.0.1 -j ACCEPT
sudo iptables -A OUTPUT -s 192.168.67.1 -o eno1 -j ACCEPT
sudo iptables -A OUTPUT -d 192.168.67.1 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 22 -s 192.168.67.1 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 10051 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
sudo iptables -P OUTPUT DROP

# Install package to save iptables rules automatically. During installation, accept the prompts twice
sudo apt install iptables-persistent -y

# *EDIT*
# Configure chroot configuration file
# Set `root-users` as needed.
sudo tee /etc/schroot/chroot.d/bionic.conf > /dev/null << 'EOF'
# Name of the chroot in square brackets. The name is subject to certain naming restrictions.
[bionic]

# A short description of the chroot. This may be localised for different languages.
description=Ubuntu 18.04 LTS (Bionic Beaver)

# This should be a directory that is outside of the /home tree.
# The latest schroot documentation recommends /srv/chroot.
directory=/srv/ltsp/bionic

# Enable this line if the host system is 64-bit running on an amd64/x64 computer
# and the chroot is 32-bit for i386. Otherwise, leave it disabled, by adding "#" as first character.
#personality=linux32

# These are users on the host system that can invoke the schroot program and
# get direct access to the chroot system as the root user.
root-users=secret

# The type of the chroot. Valid types are 'plain', 'directory', 'file', 'loopback', 'block-device',
# 'btrfs-snapshot' and 'lvm-snapshot'. If empty or omitted, the default type is 'plain'.
# Note that 'plain' chroots do not run setup scripts and mount filesystems; 'directory' is recommended.
type=directory

# These are users on the host system that can invoke the schroot program and
# get access to the chroot system. Your username on the host system should be here.
#users=alice,bob,charlie
EOF

# Create chroot jail and install Ubuntu 18.04 (Bionic Beaver)
sudo mkdir -p /srv/ltsp/bionic
sudo debootstrap --arch=amd64 bionic /srv/ltsp/bionic/ http://archive.ubuntu.com/ubuntu/

# Add professor, assistant and student groups
sudo groupadd professor
sudo groupadd assistant
sudo groupadd student
# Add a special user ltsp_monitoring to monitor clients
sudo useradd --create-home --shell /bin/bash --groups professor ltsp_monitoring


# Grant professors sudo permissions
sudo tee /etc/sudoers.d/ltsp_roles > /dev/null << 'EOF'
%professor   ALL=(ALL:ALL) ALL
EOF

# Generate students skeleton
sudo mkdir /etc/skelStudents
sudo cp -r /etc/skel/. /etc/skelStudents/
sudo mkdir /etc/skelStudents/.monitoring
sudo touch /etc/skelStudents/.monitoring/proxy_settings

# Initialize LTSP configuration file (The optional -g sudo parameter allows users in the sudo group to edit ltsp.conf with any editor (e.g. gedit) without running sudo)
sudo install -m 0660 -g sudo /usr/share/ltsp/common/ltsp/ltsp.conf /etc/ltsp/ltsp.conf

# Disallow students to ssh into the server
sudo tee -a /etc/ssh/sshd_config > /dev/null << 'EOF'
Match Group *,!sudo,!root,!professor,!assistant
    ChrootDirectory /home
    ForceCommand internal-sftp -d %u
Match all
EOF
