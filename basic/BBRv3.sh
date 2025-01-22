
echo
echo "********    BBRv3  冲啊  ─=≡Σ((( つ•̀ω•́)つ     ********"
echo
echo
echo "00 系统初始化 "
echo


# 标记 openssl 不更新，否则会让选择配置文件所在地
# sudo apt-mark hold libcurl4-openssl-dev openssh-sftp-server openssh-server


# 初始化
apt update -y

# 如果标记不更新，可能会有安全问题，因此使用这个命令，单独无交互弹窗安装 openssl 及对应依赖
DEBIAN_FRONTEND=noninteractive apt upgrade openssl -y

apt upgrade -y

apt install -y wget gnupg gpg

# 清理旧的包
apt autoremove -y

echo
echo
echo "01 检测 CPU 架构"
echo
level=0

# 读取 /proc/cpuinfo 文件，检查 flags 行
while read -r line; do
    if [[ "$line" =~ flags ]]; then
        break
    fi
done < /proc/cpuinfo

# 检查 CPU 支持的特性
if [[ "$line" =~ lm && "$line" =~ cmov && "$line" =~ cx8 && "$line" =~ fpu && "$line" =~ fxsr && "$line" =~ mmx && "$line" =~ syscall && "$line" =~ sse2 ]]; then
    level=1
fi

if [[ $level -eq 1 && "$line" =~ cx16 && "$line" =~ lahf && "$line" =~ popcnt && "$line" =~ sse4_1 && "$line" =~ sse4_2 && "$line" =~ ssse3 ]]; then
    level=2
fi

if [[ $level -eq 2 && "$line" =~ avx && "$line" =~ avx2 && "$line" =~ bmi1 && "$line" =~ bmi2 && "$line" =~ f16c && "$line" =~ fma && "$line" =~ abm && "$line" =~ movbe && "$line" =~ xsave ]]; then
    level=3
fi

if [[ $level -eq 3 && "$line" =~ avx512f && "$line" =~ avx512bw && "$line" =~ avx512cd && "$line" =~ avx512dq && "$line" =~ avx512vl ]]; then
    level=4
fi

if [[ $level -gt 0 ]]; then
    echo
    echo "CPU 支持 XanMod-x64v$level "
    echo
    echo

else
    echo "该 CPU 不支持 BBRv3 "
fi

echo
echo
echo "02 注册 PGP 密钥 "



# 注册 PGP 密钥
# wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg

## 发现原来的地址用阿里访问一直出现 403，且会跳转到 gitlab 上去
# wget -qO - https://gitlab.com/afrd.gpg | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg

# 定义密钥文件路径，在每次请求前都清理一遍
KEYRING_PATH="/usr/share/keyrings/xanmod-archive-keyring.gpg"
echo
echo "请求主站点..."
rm -f "$KEYRING_PATH"  # 删除可能存在的密钥文件
if wget -qO - https://dl.xanmod.org/archive.key | yes | gpg --dearmor -o "$KEYRING_PATH"; then
    echo "密钥添加成功!"
else
    echo "添加失败，正在请求备用地址..."
    rm -f "$KEYRING_PATH"  # 删除可能存在的密钥文件
    if wget -qO - https://gitlab.com/afrd.gpg | yes | gpg --dearmor -o "$KEYRING_PATH"; then
        echo "密钥添加成功!"
    else
        echo "密钥添加失败，请手动处理，或更换系统后再试"
        exit 1
    fi
fi


echo
echo
echo "03 添加存储库 "
echo
# 添加存储库(源)
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list
echo
echo "04 Install "
echo
# 安装
apt update -y
apt install linux-xanmod-x64v${level} -y


echo
echo "05 开启 BBRv3 "
echo
# 开启 BBR3
cat > /etc/sysctl.conf << EOF
net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr
EOF


# 加载配置
sysctl -p



echo
echo "XanMod 内核 + BBRv3 启用成功"
echo "清理环境，自动重启"
rm -f /etc/apt/sources.list.d/xanmod-release.list

echo
echo
echo "********    MM 我要起飞 La～   ********"
echo
echo " ✧(๑•̀ㅂ•́)و▄︻┻┳━══━━  ·.\`.\`.\`.　"
echo
echo

# 重启，优雅的处理正在执行的服务
reboot