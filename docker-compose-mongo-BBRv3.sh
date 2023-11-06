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

# Create mongoDB
mkdir -p /root/mongo /root/mongo/data /root/mongo/log /root/mongo/config

# Write file content
cat <<EOF > /root/docker-compose.yml
---
version: "3.9"
services:
  mongodb:
    container_name: mongo
    image: mongo:latest
    restart: always
    ports:
      - 8080:27017
    volumes:
      - ./mongo/data:/data/db
      - ./mongo/log:/var/log/mongodb
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: 77Q1PNEi2Y20&
EOF

# start mongoDB
docker compose up -d





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
docker ps
echo
echo "********   安装 BBRv3   ********"


wget "https://raw.githubusercontent.com/BLOSEregedit/shtools/main/BBRv3.sh" && chmod +x BBRv3.sh && bash BBRv3.sh



