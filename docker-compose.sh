#!/bin/bash
# 标记 openssl 不更新，否则会让选择配置文件所在地
sudo apt-mark hold libcurl4-openssl-dev openssh-sftp-server openssh-server
# Update packages
apt update -y
apt upgrade -y

# Install necessary dependencies
apt install curl apt-transport-https ca-certificates software-properties-common gnupg -y

# Install dig
apt install dnsutils -y

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up Docker's stable repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists
apt update

# Install Docker
apt install docker-ce docker-ce-cli containerd.io -y

# Download and install Docker Compose binary to /root/ directory
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /root/docker-compose

# Add execution permissions to the binary file
chmod +x /root/docker-compose

# Open ~/.bashrc and append export command at the end
echo 'export PATH="/root:$PATH"' >> ~/.bashrc

# Reload
source ~/.bashrc

# Create configuration file
touch /root/docker-compose.yml

echo
echo
echo "********   安装完成   ********"
echo
echo
# Verify
curl --version
echo
dig -v
echo
docker --version
echo
docker-compose --version
echo

