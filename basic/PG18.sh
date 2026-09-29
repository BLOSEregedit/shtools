#!/usr/bin/env bash
# 官方安装依据：https://www.postgresql.org/download/linux/debian/
# 独立入口；PG17.sh 和 PG18.sh 仅 PG_MAJOR 不同。
set -Eeuo pipefail
export LC_ALL=C
readonly PG_MAJOR=18
fail() { printf '错误：%s\n' "$*" >&2; exit 1; }
trap 'printf "安装失败（第 %s 行）。已完成的包更新不会自动回滚，请检查上方错误。\n" "$LINENO" >&2' ERR

[[ $# -eq 0 ]] || fail '本脚本不接受参数。'
[[ $(uname -s) == Linux ]] || fail '仅支持 Linux。'
[[ -r /etc/os-release ]] || fail '无法识别系统。'
. /etc/os-release
major=${VERSION_ID%%.*}
[[ $major =~ ^[0-9]+$ ]] || fail '无法识别系统主版本。'
case "$ID" in
    debian) (( major >= 13 )) || fail '需要 Debian 13 或更新版本。' ;;
    ubuntu) (( major >= 24 )) || fail '需要 Ubuntu 24 或更新版本。' ;;
    *) fail '仅支持 Debian 和 Ubuntu。' ;;
esac
[[ ${VERSION_CODENAME:-} =~ ^[a-z]+$ ]] || fail '缺少有效发行版代号。'
[[ $EUID -eq 0 ]] || fail '请使用 root 或 sudo bash 执行。'
[[ -d /run/systemd/system ]] || fail '需要运行 systemd 的服务器。'
command -v apt-get >/dev/null || fail '未找到 APT。'

# 新机或本脚本默认集群的重复运行；不处理跨大版本迁移、多集群和自定义端口。
installed_packages=$(dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' 'postgresql*' 2>/dev/null || true)
while read -r package status; do
    [[ $status == installed ]] || continue
    [[ $package != postgresql && $package != postgresql-client ]] \
        || fail '已安装会跟随大版本的 PostgreSQL 元包，请先人工核对。'
    if [[ $package =~ ^postgresql-([0-9]+)(:.*)?$ ]]; then
        [[ ${BASH_REMATCH[1]} == "$PG_MAJOR" ]] || fail "已安装其他大版本：$package；不会迁移或删除。"
    fi
done <<< "$installed_packages"
if command -v pg_lsclusters >/dev/null; then
    clusters=$(pg_lsclusters --no-header)
    while read -r version name port rest; do
        [[ -n $version ]] || continue
        [[ $version == "$PG_MAJOR" && $name == main && $port == 5432 ]] \
            || fail '检测到其他版本、多集群或非默认端口，请人工处理。'
    done <<< "$clusters"
fi

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
arch=$(dpkg --print-architecture)
source_file=/etc/apt/sources.list.d/pgdg.sources
key_file=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc
cat > "$scratch/pgdg.sources" <<EOF
Types: deb
URIs: https://apt.postgresql.org/pub/repos/apt
Suites: ${VERSION_CODENAME}-pgdg
Architectures: $arch
Components: main
Signed-By: $key_file
EOF
# 不覆盖用户维护的 PGDG 源；不同写法也交由人工核对。
if [[ -e $source_file ]]; then
    cmp -s "$scratch/pgdg.sources" "$source_file" || fail "已有不同的 $source_file，请人工核对后再执行。"
fi
for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [[ -f $file && $file != "$source_file" ]] || continue
    if grep -Eq '^[[:space:]]*[^#].*apt\.postgresql\.org' "$file"; then
        fail "已有另一份 PGDG 源：$file；请先消除重复配置。"
    fi
done

export DEBIAN_FRONTEND=noninteractive
apt_options=(-o DPkg::Lock::Timeout=300 -o Acquire::Retries=3
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
printf '01 更新索引、安装依赖（不执行全系统 upgrade）。\n'
apt-get "${apt_options[@]}" -o APT::Update::Error-Mode=any update
apt-get "${apt_options[@]}" --no-remove -y install ca-certificates curl
curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --connect-timeout 20 --max-time 180 \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc -o "$scratch/pgdg.asc"
install -d -m 0755 /usr/share/postgresql-common/pgdg
install -m 0644 "$scratch/pgdg.asc" "$key_file"
install -m 0644 "$scratch/pgdg.sources" "$source_file"

printf '02 核验官方签名索引并选取 PostgreSQL %s 稳定包。\n' "$PG_MAJOR"
chmod 0755 "$scratch"
install -d -m 0755 "$scratch/lists"
# 排除本机已安装版本和其他软件源，确保候选来自官方仓库。
official_options=(-o "Dir::Etc::sourcelist=$source_file" -o Dir::Etc::sourceparts=-
    -o "Dir::State::lists=$scratch/lists" -o Dir::State::status=/dev/null)
apt-get "${apt_options[@]}" "${official_options[@]}" -o APT::Update::Error-Mode=any update
select_candidate() {
    local package=$1 policy candidate installed
    if ! policy=$(apt-cache "${official_options[@]}" policy "$package"); then
        fail "读取官方候选失败：$package"
    fi
    candidate=$(awk '/Candidate:/ && !found {print $2; found=1}' <<< "$policy")
    [[ $candidate =~ ^${PG_MAJOR}\.[0-9]+-.*pgdg ]] || fail "无官方稳定候选：$package ${candidate:-无}"
    installed=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)
    if [[ -n $installed ]] && dpkg --compare-versions "$installed" gt "$candidate"; then
        fail "已安装的 $package $installed 高于官方候选 $candidate，不自动降级。"
    fi
    printf '%s' "$candidate"
}
server_package=postgresql-$PG_MAJOR
client_package=postgresql-client-$PG_MAJOR
server_version=$(select_candidate "$server_package")
client_version=$(select_candidate "$client_package")
[[ $server_version == "$client_version" ]] || fail '官方服务端和客户端版本不一致。'
(
    cd "$scratch"
    apt-get "${apt_options[@]}" "${official_options[@]}" download \
        "$server_package=$server_version" "$client_package=$client_version"
)
packages=("$scratch"/*.deb)
[[ ${#packages[@]} -eq 2 && -f ${packages[0]} && -f ${packages[1]} ]] || fail '未取得两个官方安装包。'

printf '03 安装 PostgreSQL %s（已有同版本集群可能重启）。\n' "$server_version"
apt-get "${apt_options[@]}" -o APT::Update::Error-Mode=any update
apt-get "${apt_options[@]}" --no-remove -y -t "${VERSION_CODENAME}-pgdg" install "${packages[@]}"
[[ $(dpkg-query -W -f='${Version}' "$server_package") == "$server_version" ]] || fail '服务端包版本不一致。'
[[ $(dpkg-query -W -f='${Version}' "$client_package") == "$client_version" ]] || fail '客户端包版本不一致。'
[[ -f /etc/postgresql/$PG_MAJOR/main/postgresql.conf ]] || fail '未创建默认 main 集群，请检查 postgresql-common 配置。'

printf '04 验证集群、开机启动和实际 SQL 连接。\n'
# 使用 Debian 的 auto 启动机制；不更改既有集群的启动策略。
start_mode=$(sed 's/#.*//; /^[[:space:]]*$/d; s/[[:space:]]//g' "/etc/postgresql/$PG_MAJOR/main/start.conf")
[[ $start_mode == auto ]] || fail 'main 集群不是 auto 启动模式，请人工核对。'
systemctl enable postgresql
systemctl daemon-reload
systemctl start "postgresql@$PG_MAJOR-main"
systemctl is-active --quiet "postgresql@$PG_MAJOR-main"
systemctl is-enabled --quiet postgresql
psql_bin=/usr/lib/postgresql/$PG_MAJOR/bin/psql
actual_version=$(runuser -u postgres -- "$psql_bin" -X -h /var/run/postgresql -p 5432 -d postgres -Atc 'SHOW server_version_num')
expected_patch=${server_version%%-*}
expected_num=$((PG_MAJOR * 10000 + ${expected_patch#*.}))
[[ $actual_version == "$expected_num" ]] || fail "实际运行版本 $actual_version 与安装包 $server_version 不一致。"
runuser -u postgres -- "$psql_bin" -X -h /var/run/postgresql -p 5432 -d postgres -c 'SELECT version();'
printf '安装完成：PostgreSQL %s，main 集群已运行并设置开机启动。\n' "$server_version"
printf '配置：/etc/postgresql/%s/main/\n数据：/var/lib/postgresql/%s/main/\n端口：5432\n' "$PG_MAJOR" "$PG_MAJOR"
printf '未创建业务账号或数据库，未配置远程访问，未迁移任何数据。\n'
