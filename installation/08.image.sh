#!/bin/bash
# Image configuration

# Copy the chroot keys in the server. LTSP will copy them again in the clients (otherwise, these keys are flushed at client startup)
sudo cp /srv/ltsp/bionic/etc/ssh/ssh_host_* /etc/ltsp/
# Create squashfs image, initialize iPXE menu, serve the chroot over NFS and generate additionnal initrd
sudo ltsp image bionic
sudo ltsp ipxe
sudo ltsp nfs
sudo ltsp initrd