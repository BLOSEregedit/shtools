#!/bin/bash

echo
echo "================================================================================"
echo "                 🚀 MongoDB 8.2.1 自动化部署脚本                               "
echo "                           版本: V2.2                                         "
echo "================================================================================"
echo
echo "📦 部署版本: MongoDB 8.2.1 (TGZ 二进制模式)"
echo "📌 脚本版本: V2.2"
echo "📌 支持系统: Debian 和 RedHat/CentOS 系列"
echo "✅ 已测试兼容: Debian 12+, CentOS 9+ (包含 Stream 和衍生版本)"
echo
echo "📂 目录规划:"
echo "   • 二进制文件  /opt/mongodb/bin/"
echo "   • 配置文件    /data/mongodb/mongodb.conf"
echo "   • 数据目录    /var/lib/mongodb/"
echo "   • 日志目录    /var/log/mongodb/"
echo
echo "================================================================================"
echo
echo
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ 步骤 0/4: 系统环境检测                                                       │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo

# 检测操作系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID}"
    OS_VERSION="${VERSION_ID}"
    OS_NAME="${PRETTY_NAME}"
elif [ -f /etc/redhat-release ]; then
    OS_ID="rhel"
    OS_NAME=$(cat /etc/redhat-release)
else
    echo "❌ 无法识别操作系统类型"
    exit 1
fi

echo "📌 检测到操作系统信息："
echo "   • 系统名称: ${OS_NAME}"
echo "   • 系统ID: ${OS_ID}"
echo "   • 系统版本: ${OS_VERSION}"
echo

# 根据系统类型设置相关变量
if [[ "${OS_ID}" =~ ^(debian)$ ]]; then
    SYSTEM_TYPE="debian"
    PKG_MANAGER="apt"
    MONGODB_TGZ="mongodb-linux-x86_64-debian12-8.2.1.tgz"
    MONGODB_URL="https://fastdl.mongodb.org/linux/${MONGODB_TGZ}"
    MONGOSH_PKG="mongodb-mongosh_2.5.9_amd64.deb"
    MONGOSH_URL="https://downloads.mongodb.com/compass/${MONGOSH_PKG}"
    echo "✅ 识别为 Debian 系统"
elif [[ "${OS_ID}" =~ ^(rhel|centos|rocky|almalinux)$ ]]; then
    SYSTEM_TYPE="redhat"
    PKG_MANAGER="dnf"
    MONGODB_TGZ="mongodb-linux-x86_64-rhel93-8.2.1.tgz"
    MONGODB_URL="https://fastdl.mongodb.org/linux/${MONGODB_TGZ}"
    MONGOSH_PKG="mongodb-mongosh-2.5.9.x86_64.rpm"
    MONGOSH_URL="https://downloads.mongodb.com/compass/${MONGOSH_PKG}"
    echo "✅ 识别为 RedHat/CentOS 系统"
else
    echo "❌ 不支持的操作系统: ${OS_ID}"
    echo "   目前仅支持: Debian 和 RedHat/CentOS 系列"
    exit 1
fi

echo
echo "📦 将使用以下安装包："
echo "   • MongoDB: ${MONGODB_TGZ}"
echo "   • Mongosh: ${MONGOSH_PKG}"
echo "   • 包管理器: ${PKG_MANAGER}"
echo

echo
echo
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ 步骤 1/4: 系统基础更新与依赖安装                                             │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo

# 根据系统类型执行不同的包管理命令
if [ "${SYSTEM_TYPE}" = "debian" ]; then
    # Debian 系统
    echo "📌 更新系统软件包 (Debian - apt)..."
    apt update -y
    apt upgrade -y

    echo
    echo "📌 安装基础工具 (wget, curl, bc, tar)..."
    apt install wget curl bc tar -y

    echo
    echo "📌 安装 MongoDB 运行时依赖库..."
    apt install libcurl4 libgssapi-krb5-2 libldap-common libwrap0 libsasl2-2 libsasl2-modules libsasl2-modules-gssapi-mit openssl liblzma5 -y
else
    # RedHat/CentOS 系统
    echo "📌 更新系统软件包 (RedHat/CentOS - dnf)..."
    dnf update -y

    echo
    echo "📌 安装基础工具 (wget, curl, bc, tar)..."
    dnf install wget curl bc tar -y

    echo
    echo "📌 安装 MongoDB 运行时依赖库..."
    dnf install libcurl openssl xz-libs cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs openldap -y
fi

echo
echo "✅ 系统依赖安装完成"
echo
echo
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ 步骤 2/4: 下载 MongoDB 文件                                                  │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo
DOWNLOAD_DIR="/root"
CONFIG_DIR="/data/mongodb"
CONFIG_FILE="${CONFIG_DIR}/mongodb.conf"

# 创建配置文件目录
echo "📌 创建配置文件目录..."
echo "   → ${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}"

# 下载 MongoDB 配置文件到指定目录
echo
echo "📌 下载配置文件..."
echo "   → 目标: ${CONFIG_FILE}"
echo "   → 来源: GitHub repository"
wget -O "${CONFIG_FILE}" https://raw.githubusercontent.com/BLOSEregedit/shtools/refs/heads/main/scp/mongodb.conf

# 下载 MongoDB 压缩包
echo
echo "📌 下载 MongoDB 二进制包..."
echo "   → 系统类型: ${SYSTEM_TYPE}"
echo "   → 文件: ${MONGODB_TGZ}"
echo "   → 大小: ~500MB，请耐心等待..."
wget -O "${DOWNLOAD_DIR}/${MONGODB_TGZ}" "${MONGODB_URL}"

echo
echo "✅ 文件下载完成"
echo
echo
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ 步骤 3/4: 解压安装与目录初始化                                               │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo

INSTALL_DIR="/opt/mongodb"
DATA_DIR="/var/lib/mongodb"
LOG_DIR="/var/log/mongodb"
PID_DIR="/var/run/mongodb"

echo "📌 初始化目录结构..."
echo "   → 执行目录: ${INSTALL_DIR}"
echo "   → 数据目录: ${DATA_DIR}"
echo "   → 日志目录: ${LOG_DIR}"
echo "   → PID 目录: ${PID_DIR}"

# 创建安装目录、数据目录和日志目录
mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "${LOG_DIR}" "${PID_DIR}"

echo
echo "📌 解压 MongoDB 压缩包..."
# 解压到 /opt/mongodb 目录，并去除压缩包中的顶层目录
tar -zxvf "${DOWNLOAD_DIR}/${MONGODB_TGZ}" -C "${INSTALL_DIR}" --strip-components 1
echo
echo "   ✓ 解压完成，二进制文件位于 ${INSTALL_DIR}/bin/"

# 清理下载的压缩包
# rm "${DOWNLOAD_DIR}/${MONGODB_TGZ}"

echo
echo "✅ MongoDB 安装完成"
echo
echo
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ 步骤 4/4: 启动服务与配置管理                                                 │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo

# 自动配置 cacheSizeGB
echo "📌 检测服务器内存并配置缓存大小..."
# 获取系统总内存（单位：MB）
TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
echo "   → 检测到系统总内存: ${TOTAL_MEM_MB} MB"

# 计算 cacheSizeGB
# 公式: (总内存 - 1GB) / 2，最小 0.25GB
CACHE_SIZE_MB=$(( (TOTAL_MEM_MB - 1024) / 2 ))

# 确保最小值为 256MB (0.25GB)
if [ ${CACHE_SIZE_MB} -lt 256 ]; then
    CACHE_SIZE_MB=256
fi

# 转换为 GB（保留两位小数）
CACHE_SIZE_GB=$(echo "scale=2; ${CACHE_SIZE_MB} / 1024" | bc)

echo "   → 计算建议缓存大小: ${CACHE_SIZE_GB} GB"

# 修改配置文件中的 cacheSizeGB
sed -i "s/cacheSizeGB: [0-9]\+\(\.[0-9]\+\)\?/cacheSizeGB: ${CACHE_SIZE_GB}/g" "${CONFIG_FILE}"

echo "   ✓ 配置文件已更新: cacheSizeGB = ${CACHE_SIZE_GB} GB"

echo
echo "📌 启动 MongoDB 进程..."
# 依赖配置文件中的 fork 选项在后台运行
"${INSTALL_DIR}/bin/mongod" -f "${CONFIG_FILE}" --logpath "${LOG_DIR}/mongod.log" --logappend --pidfilepath "${PID_DIR}/mongod.pid"

sleep 5 # 等待服务启动

echo "   ✓ MongoDB 进程已在后台启动"
echo "   ℹ 日志文件: ${LOG_DIR}/mongod.log"
echo
echo
echo
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ 附加工具: 安装 mongosh 客户端                                                │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo

if [ "${SYSTEM_TYPE}" = "debian" ]; then
    # Debian 系统 - 使用 DEB 包
    echo "📌 准备目录..."
    mkdir -p /data/mongosh /opt/mongodb/bin

    echo
    echo "📌 下载 mongosh 2.5.9 (Debian - DEB 包)..."
    wget -O /root/${MONGOSH_PKG} ${MONGOSH_URL}

    echo
    echo "📌 解压 DEB 包..."
    dpkg -x /root/${MONGOSH_PKG} /data/mongosh

    echo
    echo "📌 移动可执行文件并创建软链接..."
    mv /data/mongosh/usr/bin/mongosh /opt/mongodb/bin/
    ln -sf /opt/mongodb/bin/mongosh /usr/local/bin/mongosh

    # 清理临时文件
    # rm -f /root/${MONGOSH_PKG}
    # rm -rf /data/mongosh
else
    # RedHat/CentOS 系统 - 使用 RPM 包
    echo "📌 准备目录..."
    mkdir -p /opt/mongodb/bin

    echo
    echo "📌 下载 mongosh 2.5.9 (RedHat/CentOS - RPM 包)..."
    wget -O /root/${MONGOSH_PKG} ${MONGOSH_URL}

    echo
    echo "📌 安装 RPM 包..."
    rpm -ivh /root/${MONGOSH_PKG}

    echo
    echo "📌 创建软链接..."
    ln -sf /usr/bin/mongosh /opt/mongodb/bin/mongosh

    # 清理临时文件
    # rm -f /root/${MONGOSH_PKG}
fi

echo
echo "✅ mongosh 安装完成"

echo
echo
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ 数据库配置: 创建用户与数据库                                                 │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo

# 客户端连接并创建用户
echo "📌 创建管理员用户 'scp'..."
# 直接使用全局可用的 'mongosh' 命令
# 指定端口 37017
mongosh --port 37017 --eval 'db.getSiblingDB("admin").createUser({ user: "scp", pwd: "11223344", roles: [{ role: "root", db: "admin" }] });'

# 验证登录
echo
echo "📌 验证用户登录..."
mongosh --port 37017 -u "scp" -p "11223344" --authenticationDatabase "admin" --eval 'print("User scp connected successfully.")'

# 创建 supercache 数据库
echo
echo "📌 创建 'supercache' 数据库..."
mongosh --port 37017 -u "scp" -p "11223344" --authenticationDatabase "admin" --eval 'db.getSiblingDB("supercache").createCollection("_init"); print("Database supercache created successfully.");'

# 简单的完成提示
echo
echo "✅ 用户与数据库配置完成"


echo
echo
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ 安全配置: 启用认证模式                                                       │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo

echo "📌 停止当前 MongoDB 进程..."
# 通过 PID 文件停止进程
if [ -f "${PID_DIR}/mongod.pid" ]; then
    MONGOD_PID=$(cat "${PID_DIR}/mongod.pid")
    kill "${MONGOD_PID}"
    sleep 3
    echo "   ✓ MongoDB 进程已停止 (PID: ${MONGOD_PID})"
else
    echo "   ⚠️  未找到 PID 文件，尝试通过进程名停止..."
    pkill -f "mongod.*${CONFIG_FILE}"
    sleep 3
fi

echo
echo "📌 修改配置文件，启用认证..."
sed -i 's/authorization: disabled/authorization: enabled/g' "${CONFIG_FILE}"
echo "   ✓ 配置已更新: authorization: enabled"

echo
echo "✅ 安全配置完成"


echo
echo
echo "┌─────────────────────────────────────────────────────────────────────────────┐"
echo "│ SystemD 服务: 配置并启动系统服务                                             │"
echo "└─────────────────────────────────────────────────────────────────────────────┘"
echo
SYSTEMD_FILE="/etc/systemd/system/mongodb.service"
CONFIG_FILE="/data/mongodb/mongodb.conf"
MONGOD_BIN="/opt/mongodb/bin/mongod"

echo "📌 创建 mongodb.service 文件..."
# 使用 root 用户运行，与先前脚本中 root 角色的选择保持一致。
cat > "${SYSTEMD_FILE}" << EOF
[Unit]
Description=MongoDB Database Server
Documentation=https://docs.mongodb.org/manual
After=network-online.target
Wants=network-online.target

[Service]
User=root
Group=root
Type=forking
PIDFile=/var/run/mongodb/mongod.pid
ExecStart=${MONGOD_BIN} --config ${CONFIG_FILE} --pidfilepath /var/run/mongodb/mongod.pid

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "   ✓ 服务文件已创建: ${SYSTEMD_FILE}"

echo
echo "📌 重新加载 SystemD 配置..."
systemctl daemon-reload

echo
echo "📌 启动 MongoDB 服务..."
systemctl start mongodb

echo
echo "📌 启用开机自启..."
systemctl enable mongodb

sleep 3

echo
echo "📌 检查服务状态..."
if systemctl is-active --quiet mongodb; then
    echo "   ✓ MongoDB 服务运行正常"
else
    echo "   ⚠️  服务启动异常，请检查日志: journalctl -u mongodb -n 50"
fi

echo
echo "✅ SystemD 服务配置并启动完成"


echo

echo
echo
echo
echo "================================================================================"
echo "                          ✨ 部署完成总览                                      "
echo "                           脚本版本: V2.2                                      "
echo "================================================================================"
echo
echo "🖥️  服务器信息："
echo "   • 操作系统: ${OS_NAME}"
echo "   • 系统类型: ${SYSTEM_TYPE}"
echo "   • 包管理器: ${PKG_MANAGER}"
echo "   • 系统内存: ${TOTAL_MEM_MB} MB"
echo
echo "✅ 已完成的操作："
echo "   1. 系统基础更新 + 安装依赖库"
echo "   2. 下载并安装 MongoDB 8.2.1 (${MONGODB_TGZ})"
echo "   3. 下载并安装 mongosh 2.5.9 (${MONGOSH_PKG})"
echo "   4. 根据服务器内存自动配置最佳缓存参数 (cacheSizeGB)"
echo "   5. 创建管理员用户 'scp' (密码: 11223344)"
echo "   6. 创建项目数据库 'supercache'"
echo "   7. 启用认证模式 (authorization: enabled)"
echo "   8. 配置 SystemD 服务并启用开机自启"
echo "   9. 使用 SystemD 启动 MongoDB 服务"

echo
echo "📂 关键目录："
echo "   • 二进制文件   /opt/mongodb/bin/"
echo "   • 配置文件     /data/mongodb/mongodb.conf"
echo "   • 数据目录     /var/lib/mongodb/"
echo "   • 日志目录     /var/log/mongodb/"
echo "   • PID 文件     /var/run/mongodb/mongod.pid"
echo
echo "🔧 配置要点："
echo "   • 监听端口     37017 (非默认端口)"
echo "   • 绑定地址     0.0.0.0 (允许远程连接)"
echo "   • 认证模式     已启用 (authorization: enabled)"
echo "   • 缓存大小     ${CACHE_SIZE_GB} GB (已根据服务器内存 ${TOTAL_MEM_MB} MB 自动优化)"
echo "   • 管理员       scp / 11223344 (admin 数据库)"
echo "   • 项目数据库   supercache"
echo "   • 运行用户     root"
echo "   • 服务状态     已启动并启用开机自启"
echo
echo "================================================================================"
echo "                          🔍 验证步骤                                          "
echo "================================================================================"
echo
echo "1️⃣  检查进程是否运行："
echo "   ps aux | grep mongod"
echo
echo "2️⃣  检查端口是否监听："
echo "   netstat -tuln | grep 37017"
echo "   # 或使用: ss -tuln | grep 37017"
echo
echo "3️⃣  查看日志文件："
echo "   tail -f /var/log/mongodb/mongod.log"
echo
echo "4️⃣  连接到 supercache 数据库（推荐）："
echo "   mongosh --port 37017 -u scp -p 11223344 --authenticationDatabase admin supercache"
echo
echo "5️⃣  验证 mongosh 版本："
echo "   mongosh --version"
echo
echo "6️⃣  检查 SystemD 服务状态："
echo "   systemctl status mongodb"
echo
echo "7️⃣  查看服务日志："
echo "   journalctl -u mongodb -f"
echo
echo "================================================================================"
echo "                          ⚙️  SystemD 服务管理                                 "
echo "================================================================================"
echo
echo "服务控制命令："
echo "   systemctl status mongodb     # 查看服务状态"
echo "   systemctl stop mongodb       # 停止服务"
echo "   systemctl restart mongodb    # 重启服务"
echo "   systemctl disable mongodb    # 禁用开机自启"
echo
echo "查看日志："
echo "   journalctl -u mongodb -f     # 实时查看服务日志"
echo "   journalctl -u mongodb -n 100 # 查看最近 100 行日志"
echo
echo "================================================================================"
echo "                          ⚠️  安全提示                                         "
echo "================================================================================"
echo
echo "  • 当前使用 ROOT 用户运行 MongoDB（生产环境建议创建专用用户）"
echo "  • 默认密码为 '11223344'，生产环境请务必修改为强密码"
echo "  • 配置文件位于 /data/mongodb/mongodb.conf，可根据需要调整"
echo "  • 远程连接需确保防火墙开放 37017 端口"
echo "  • 认证模式已启用，必须使用用户名密码连接"
echo "  • MongoDB 已通过 SystemD 管理，开机自动启动"
echo
echo "================================================================================"
echo "                          🎉 部署成功！                                        "
echo "================================================================================"
echo
