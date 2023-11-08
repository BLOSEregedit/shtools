# 标记 openssl 不更新，否则会让选择配置文件所在地
sudo apt-mark hold libcurl4-openssl-dev openssh-sftp-server openssh-server


# 初始化
apt update -y
apt upgrade -y


apt install -y wget gnupg

# 注册 PGP 密钥
wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes


# 添加存储库
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list


# 安装
apt update -y && apt install -y linux-xanmod-x64v4

# 开启 BBR3
cat > /etc/sysctl.conf << EOF
net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr
EOF


# 加载配置
sysctl -p
echo
echo "XanMod 内核安装并 BBR3 启用成功。重启后生效"
echo
rm -f /etc/apt/sources.list.d/xanmod-release.list


# 重启
reboot