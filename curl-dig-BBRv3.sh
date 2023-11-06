#!/bin/bash

# Update packages
apt update -y
apt upgrade -y

# Install necessary dependencies
apt install curl apt-transport-https ca-certificates software-properties-common gnupg -y

# Install dig
apt install dnsutils -y

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg


# Verify
echo
curl --version
echo
dig -v


# Print an empty line
echo
echo

# Print a prompt message
echo "现在执行 BBRv3 开启，之后会重启服务器"
# Print an empty line
echo
echo


# BBRv3

wget "https://raw.githubusercontent.com/BLOSEregedit/shtools/main/BBRv3.sh" && chmod +x BBRv3.sh && bash BBRv3.sh