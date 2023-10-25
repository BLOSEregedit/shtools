#!/bin/bash

# Update packages
apt update -y
apt upgrade -y

# Install necessary dependencies
apt install curl apt-transport-https ca-certificates software-properties-common gnupg -y

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

# Verify
docker --version
docker-compose --version

# Print an empty line
echo
echo

# Print a prompt message
echo "现在执行 BBR2 开启，之后会重启服务器"
# Print an empty line
echo
echo


# BBR2
wget --no-check-certificate -q -O bbr2.sh "https://github.com/yeyingorg/bbr2.sh/raw/master/bbr2.sh" && chmod +x bbr2.sh && bash bbr2.sh auto

