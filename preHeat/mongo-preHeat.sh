#!/bin/bash

# 更新系统
echo "Updating system..."
apt update -y
apt upgrade -y

# 安装必要的工具
echo "Installing necessary tools..."
apt install wget curl -y

# 安装 MongoDB 依赖
echo "Installing MongoDB dependencies..."
apt install libcurl4 libgssapi-krb5-2 libldap-common libwrap0 libsasl2-2 libsasl2-modules libsasl2-modules-gssapi-mit openssl liblzma5 -y

# 下载 MongoDB 配置文件
echo "Downloading MongoDB configuration file..."
wget -O /root/mongodb.conf https://raw.githubusercontent.com/BLOSEregedit/shtools/refs/heads/main/preHeat/mongodb.conf

# 下载 MongoDB
echo "Downloading MongoDB..."
wget -O /root/mongodb-linux-x86_64-debian12-8.0.4.tgz https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-debian12-8.0.4.tgz

# 解压 MongoDB
echo "Extracting MongoDB..."
tar -zxvf /root/mongodb-linux-x86_64-debian12-8.0.4.tgz -C /root/

# 创建数据和日志目录
echo "Creating data and log directories..."
mkdir -p /root/mongodb/data/ /root/mongodb/log/

# 启动 MongoDB
echo "Starting MongoDB..."
/root/mongodb-linux-x86_64-debian12-8.0.4/bin/mongod -f /root/mongodb.conf

echo "MongoDB installation and setup completed."
