#!/bin/bash
# 标记 openssl 不更新，否则会让选择配置文件所在地
sudo apt-mark hold libcurl4-openssl-dev openssh-sftp-server openssh-server
# Update packages
apt update -y
apt upgrade -y

# Install necessary dependencies
apt install curl apt-transport-https ca-certificates software-properties-common gnupg -y
apt install mtr -y

# Install dig
apt install dnsutils -y

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo
echo
echo "********   安装完成   ********"
# Verify
echo
echo
curl --version
echo
dig -v
echo
mtr -v
echo



