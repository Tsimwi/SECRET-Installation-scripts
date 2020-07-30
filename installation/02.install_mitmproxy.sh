#!/bin/bash
## Mitmproxy installation

## Download and install binaries
sudo mkdir /opt/mitmproxy
cd /opt/mitmproxy
sudo wget https://snapshots.mitmproxy.org/5.1.1/mitmproxy-5.1.1-linux.tar.gz
sudo tar --no-same-owner -xzf mitmproxy-5.1.1-linux.tar.gz
sudo rm mitmproxy-5.1.1-linux.tar.gz

## Manually launch mitmproxy in order to generate its certificates in /${user}/.mitmproxy
# sudo ./mitmproxy