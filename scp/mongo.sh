#!/bin/bash


echo
echo "==========     01  安装 mongoDB  ─=≡Σ((( つ•̀ω•́)つ           ==================="
echo
echo "## 部署版本: MongoDB 8.2.1 (TGZ 模式)"
echo "## 目录结构: Binaries -> /opt/mongodb/"
echo "##          Config   -> /data/mongodb/"
echo "##          Data     -> /var/lib/mongodb/"
echo "##          Logs     -> /var/log/mongodb/"
echo
echo "=============================================================================="
echo
echo
echo "--- 1. 系统基础更新与工具安装 ---"
# 更新系统包列表并升级已安装的包
apt update -y
apt upgrade -y
# 安装必要的工具
echo
echo "Installing necessary tools..."
apt install wget curl -y
echo
# 安装 MongoDB 运行时依赖库
echo "Installing MongoDB dependencies..."
apt install libcurl4 libgssapi-krb5-2 libldap-common libwrap0 libsasl2-2 libsasl2-modules libsasl2-modules-gssapi-mit openssl liblzma5 -y
echo
echo
echo "--- 2. 下载 MongoDB 文件 ---"
MONGODB_TGZ="mongodb-linux-x86_64-debian12-8.2.1.tgz"
MONGODB_URL="https://fastdl.mongodb.org/linux/${MONGODB_TGZ}"
DOWNLOAD_DIR="/root" # 临时下载目录
CONFIG_DIR="/data/mongodb"
CONFIG_FILE="${CONFIG_DIR}/mongodb.conf"

# 创建配置文件目录
echo "   --> 创建配置文件目录 ${CONFIG_DIR}"
mkdir -p "${CONFIG_DIR}"

# 下载 MongoDB 配置文件到指定目录
echo "   --> 下载配置文件到 ${CONFIG_FILE}"
wget -O "${CONFIG_FILE}" https://raw.githubusercontent.com/BLOSEregedit/shtools/refs/heads/main/scp/mongodb.conf


# 下载 MongoDB 压缩包
echo "   --> 下载 MongoDB 二进制压缩包 (${MONGODB_TGZ})"
wget -O "${DOWNLOAD_DIR}/${MONGODB_TGZ}" "${MONGODB_URL}"

echo
echo "--- 3. 创建目录 ---"
# (已移除) 不再创建 'mongodb' 用户，将使用 'root' 运行。

INSTALL_DIR="/opt/mongodb"
DATA_DIR="/var/lib/mongodb"
LOG_DIR="/var/log/mongodb"
PID_DIR="/var/run/mongodb"

echo "   --> 执行目录 ${INSTALL_DIR}"
echo "   --> 数据目录 ${DATA_DIR}"
echo "   --> 日志目录 ${LOG_DIR}"

# 创建安装目录、数据目录和日志目录
mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "${LOG_DIR}" "${PID_DIR}"
echo


echo "--- 4. 解压缩包 ---"
# 解压到 /opt/mongodb 目录，并去除压缩包中的顶层目录
tar -zxvf "${DOWNLOAD_DIR}/${MONGODB_TGZ}" -C "${INSTALL_DIR}" --strip-components 1
echo "   -> 解压完成，二进制文件位于 ${INSTALL_DIR}/bin/"

# 清理下载的压缩包
# rm "${DOWNLOAD_DIR}/${MONGODB_TGZ}"

echo
echo "--- 5. 启动 MongoDB 服务 ---"
# 依赖配置文件中的 fork 选项在后台运行
"${INSTALL_DIR}/bin/mongod" -f "${CONFIG_FILE}" --logpath "${LOG_DIR}/mongod.log" --logappend --pidfilepath "${PID_DIR}/mongod.pid"

sleep 5 # 等待服务启动

echo "MongoDB 进程已尝试在后台启动。请检查日志文件 ${LOG_DIR}/mongod.log"
echo
echo
echo
echo "==========     02  安装 mongosh  ─=≡Σ((( つ•̀ω•́)つ           ==================="
echo
# echo "--- 1. 准备目录 ---"
echo "创建解压目录和最终 bin 目录"
mkdir -p /data/mongosh /opt/mongodb/bin

echo " --- 2. 下载 DEB 文件  V2.5.9 ---  "
# 直接下载到 /root/ 目录下，使用完整文件名
wget -O /root/mongodb-mongosh_2.5.9_arm64.deb https://downloads.mongodb.com/compass/mongodb-mongosh_2.5.9_amd64.deb


# --- 3.  ---
echo " --- 3. 使用 dpkg -x 解压 ---  "
echo "   --> /data/mongosh/"
dpkg -x /root/mongodb-mongosh_2.5.9_arm64.deb /data/mongosh
echo
echo " --- 4. mv & 创建软链接---  "
mv /data/mongosh/usr/bin/mongosh /opt/mongodb/bin/

# 创建软链接到全局可执行路径
ln -sf /opt/mongodb/bin/mongosh /usr/local/bin/mongosh

# --- 5. 清理临时文件 ---
# 清理下载的 DEB 文件和解压目录
#rm -f /root/mongodb-mongosh_2.5.9_arm64.deb
#rm -rf /data/mongosh

# 简单的完成提示
echo "mongosh 安装完成。在任何位置运行 'mongosh --version' 即可验证。"

echo
echo
echo "==========     03  创建 mongodb 用户  ─=≡Σ((( つ•̀ω•́)つ           ==================="
echo

# 客户端连接并创建用户
echo "   -> 创建 'scp' 用户..."
# 直接使用全局可用的 'mongosh' 命令
# 指定端口 37017
mongosh --port 37017 --eval 'db.getSiblingDB("admin").createUser({ user: "scp", pwd: "11223344", roles: [{ role: "root", db: "admin" }] });'

# 验证登录
echo "   -> 验证用户登录..."
mongosh --port 37017 -u "scp" -p "11223344" --authenticationDatabase "admin" --eval 'print("User scp connected successfully.")'

# 简单的完成提示
echo "MongoDB 用户创建步骤执行完毕。"



# --- 新增 SystemD 配置模块（不启动） ---
echo
echo
echo "==========     04  集成 SystemD 服务配置 (只创建不启动)  ─=≡Σ((( つ•̀ω•́)つ           ==================="
echo
SYSTEMD_FILE="/etc/systemd/system/mongodb.service"
CONFIG_FILE="/data/mongodb/mongodb.conf"
MONGOD_BIN="/opt/mongodb/bin/mongod"

echo "--- 1. 创建 mongodb.service 文件 ---"
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
echo
echo "   -> SystemD 服务文件已创建: ${SYSTEMD_FILE}"
echo
echo "--- 2. 重新加载 SystemD 配置 ---"
systemctl daemon-reload

echo "--- 3. 启用服务 (设置开机自启) ---"
echo "   -> **注意：未执行 systemctl enable**"
# systemctl enable mongodb.service # 保持注释或移除，您会手动处理

echo "--- 4. 启动 MongoDB 服务 ---"
echo "   -> **注意：未执行 systemctl start**"
# systemctl start mongodb.service # 保持注释或移除，您会手动处理



echo
echo
echo
echo "******** ( ´∀｀)つt[ okk～ ]    ********"
echo
echo "MongoDB 部署和设置已完成。请使用 'ps aux | grep mongod' 确认进程运行。"
echo
echo
