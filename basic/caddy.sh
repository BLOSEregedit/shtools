#!/usr/bin/env bash
# 官方安装依据：https://caddyserver.com/docs/install#debian-ubuntu-raspbian
set -Eeuo pipefail
export LC_ALL=C

fail() { printf '错误：%s\n' "$*" >&2; exit 1; }
trap 'printf "安装失败（第 %s 行）。请检查上方错误；系统更新可能已经完成。\n" "$LINENO" >&2' ERR

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
[[ $EUID -eq 0 ]] || fail '请使用 root 或 sudo bash 执行本脚本。'
[[ -d /run/systemd/system ]] || fail '需要运行 systemd 的服务器。'
command -v apt-get >/dev/null || fail '未找到 APT。'

export DEBIAN_FRONTEND=noninteractive
# 常规升级可能重启服务；配置文件冲突时保留现有文件，不自动重启机器。
export NEEDRESTART_MODE=a
apt_options=(-o DPkg::Lock::Timeout=300 -o Acquire::Retries=3
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

printf '系统：%s；架构：%s\n' "$PRETTY_NAME" "$(dpkg --print-architecture)"
printf '01 更新软件索引并执行常规系统升级（可能重启服务）。\n'
apt-get "${apt_options[@]}" -o APT::Update::Error-Mode=any update
apt-get "${apt_options[@]}" -y upgrade

printf '02 安装依赖并配置 Caddy 官方稳定源。\n'
apt-get "${apt_options[@]}" -y install ca-certificates curl gnupg debian-keyring debian-archive-keyring apt-transport-https

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --connect-timeout 20 --max-time 180 \
    https://dl.cloudsmith.io/public/caddy/stable/gpg.key -o "$scratch/caddy.key"
curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --connect-timeout 20 --max-time 180 \
    https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt -o "$scratch/caddy.list"
grep -Eq '^deb .*https://dl\.cloudsmith\.io/public/caddy/stable/deb/debian ' "$scratch/caddy.list" \
    || fail '官方源文件内容不符合预期。'
gpg --batch --yes --dearmor -o "$scratch/caddy.gpg" "$scratch/caddy.key"
install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d
install -m 0644 "$scratch/caddy.gpg" /usr/share/keyrings/caddy-stable-archive-keyring.gpg
install -m 0644 "$scratch/caddy.list" /etc/apt/sources.list.d/caddy-stable.list

# 使用仅含官方稳定源的临时索引，防止系统源或 testing 源抢占候选版本。
chmod 0755 "$scratch"
install -d -m 0755 "$scratch/lists"
official_options=(-o Dir::Etc::sourcelist=/etc/apt/sources.list.d/caddy-stable.list
    -o Dir::Etc::sourceparts=- -o "Dir::State::lists=$scratch/lists")
apt-get "${apt_options[@]}" "${official_options[@]}" -o APT::Update::Error-Mode=any update
# 完整读取 APT 输出，避免 awk 提前退出触发 SIGPIPE，并保留真实查询失败。
if ! policy=$(apt-cache "${official_options[@]}" policy caddy); then
    fail '读取 Caddy 官方源候选版本失败，请检查上方 APT 错误。'
fi
candidate=$(awk '/Candidate:/ && !found {print $2; found=1}' <<< "$policy")
[[ ${candidate#*:} == 2.* ]] || fail "官方源未提供可安装的 Caddy 2：${candidate:-无}。"
installed=$(dpkg-query -W -f='${Version}' caddy 2>/dev/null || true)
if [[ -n $installed ]] && dpkg --compare-versions "$installed" gt "$candidate"; then
    fail "已安装版本 $installed 高于官方稳定版本 $candidate，不自动降级。"
fi

printf '03 安装官方稳定版本：%s\n' "$candidate"
# 先从隔离的官方索引下载指定版本，再由系统 APT 处理依赖。
(
    cd "$scratch"
    apt-get "${apt_options[@]}" "${official_options[@]}" download "caddy=$candidate"
)
packages=("$scratch"/caddy_*.deb)
[[ ${#packages[@]} -eq 1 && -f ${packages[0]} ]] || fail '未取得唯一的 Caddy 安装包。'
apt-get "${apt_options[@]}" -y install "${packages[0]}"

printf '04 验证安装与服务。\n'
[[ $(dpkg-query -W -f='${Version}' caddy) == "$candidate" ]] || fail '安装版本与官方候选版本不一致。'
/usr/bin/caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl enable --now caddy
systemctl is-active --quiet caddy
systemctl is-enabled --quiet caddy
/usr/bin/caddy version
printf '安装完成：Caddy 服务已运行，并已设置开机启动。\n配置文件：/etc/caddy/Caddyfile\n默认网站目录：/usr/share/caddy\n'
if [[ -f /var/run/reboot-required ]]; then
    printf '系统更新提示需要重启，请自行安排；脚本不会自动重启机器。\n'
fi
