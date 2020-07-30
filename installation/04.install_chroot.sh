#!/bin/bash
# Chrooted environment configuration
# This script must be called from inside the chroot

# Fill apt sources list
cat > /etc/apt/sources.list << 'EOF'
deb http://us.archive.ubuntu.com/ubuntu/ bionic main restricted
deb http://us.archive.ubuntu.com/ubuntu/ bionic-updates main restricted
deb http://us.archive.ubuntu.com/ubuntu/ bionic universe
deb http://us.archive.ubuntu.com/ubuntu/ bionic-updates universe
deb http://us.archive.ubuntu.com/ubuntu/ bionic multiverse
deb http://us.archive.ubuntu.com/ubuntu/ bionic-updates multiverse
deb http://us.archive.ubuntu.com/ubuntu/ bionic-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu bionic-security main restricted
deb http://security.ubuntu.com/ubuntu bionic-security universe
deb http://security.ubuntu.com/ubuntu bionic-security multiverse
EOF

# Prepare new repositories
apt update && apt upgrade -y
apt install software-properties-common -y
add-apt-repository ppa:ltsp -y

# Install Ubuntu desktop and others packages (skip GRUB installation)
apt update
apt install --install-recommends ltsp -y
apt install ubuntu-desktop nano linux-generic openssh-server iptables-persistent -y

# Set date
rm /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# Generate locales
locale-gen en_US.UTF-8

# Install mitmproxy certificate :
update-ca-certificates

# Prepare gnome environment
cat > /etc/dconf/profile/user << 'EOF'
user-db:user
system-db:local
EOF
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/local << 'EOF'
[system/proxy]
mode='manual'
ignore-hosts=['localhost','127.0.0.1']

[system/proxy/http]
host='192.168.67.1'
port=8080
enabled=true

[system/proxy/https]
host='192.168.67.1'
port=8080
enabled=true
EOF
dconf update

# Add mitmproxy certificate in Firefox
cat > /usr/lib/firefox/distribution/policies.json << 'EOF'
{
    "policies": {
        "Certificates": {
            "Install": [
                "Mitmproxy",
                "/usr/local/share/ca-certificates/mitmproxy-ca-cert.crt"
            ]
        }
    }
}
EOF
