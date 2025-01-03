#!/bin/bash

echo
echo "********    安装 curl ｜ mtr ｜ dig     ─=≡Σ((( つ•̀ω•́)つ     ********"
echo
echo "01 初始化 "
echo

# 标记 openssl 不更新，否则会让选择配置文件所在地
sudo apt-mark hold libcurl4-openssl-dev openssh-sftp-server openssh-server

# Update packages
apt update -y
apt upgrade -y


echo
echo "01 Install curl "
echo
# Install necessary dependencies
apt install curl apt-transport-https ca-certificates software-properties-common gnupg -y

echo
echo "02 Install mtr "
echo
apt install mtr -y


echo
echo "03 Install dig "
echo
apt install dnsutils -y

echo
echo "04 Install nload"
echo
apt install nload -y

echo
echo "05 Install htop  "
echo
apt install htop -y


echo
echo "06 Install aria2 screen "
echo
apt install aria2 screen -y

echo
echo
echo "********     安装完成  ( ´∀｀)つt[ ]    ********"
# Verify
echo
echo
curl --version
echo
mtr -v
echo
dig -v
echo