
## docker
wget https://raw.githubusercontent.com/BLOSEregedit/shtools/main/basic/docker.sh && chmod +x docker.sh && ./docker.sh


echo
echo "********    安装 docker-compose  ─=≡Σ((( つ•̀ω•́)つ     ********"
echo
echo "01 install "
echo

# Download and install Docker Compose binary to /root/ directory
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /root/docker-compose

# Add execution permissions to the binary file
chmod +x /root/docker-compose

echo
echo "02 配置环境 "
echo

# Open ~/.bashrc and append export command at the end
echo 'export PATH="/root:$PATH"' >> ~/.bashrc

# Reload
source ~/.bashrc


echo
echo "03 创建 yml 文件   -->   /root/docker-compose.yml"
echo

# Create configuration file
touch /root/docker-compose.yml


echo
echo "********     安装完成  ( ´∀｀)つt[ ]    ********"
echo
docker --version
echo
docker-compose --version
echo