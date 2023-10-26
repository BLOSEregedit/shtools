#!/bin/bash
echo
echo "********   00 服务器初始化   ********"
echo
# Update packages
apt update -y
apt upgrade -y
apt install expect -y

echo
echo "********   01 install curl dig   ********"
echo

# Install necessary dependencies
apt install curl apt-transport-https ca-certificates software-properties-common gnupg -y

# Install dig
apt install dnsutils -y

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

mkdir -p /etc/apt/keyrings

curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg


echo
echo "********   02 安装 nodejs   ********"
echo

NODE_MAJOR=16
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list


apt update -y
apt install nodejs -y

echo
echo "********   03 安装 Akamai-cli   ********"
echo "********   -- 注意需要手动操作，出现提示框，按回车默认选择即可   ********"
echo

wget https://github.com/akamai/cli/releases/download/v1.5.5/akamai-v1.5.5-linux386 && chmod +x akamai-v1.5.5-linux386 && ./akamai-v1.5.5-linux386

echo
echo "********   04 安装 Edgeworkers   ********"
echo

akamai update



akamai install edgeworkers




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
echo
akamai --version
echo
echo
akamai edgeworkers -V
echo
echo
