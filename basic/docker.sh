#!/usr/bin/env bash
# 官方依据：https://docs.docker.com/engine/install/debian/
# https://docs.docker.com/engine/install/ubuntu/
set -Eeuo pipefail
export LC_ALL=C

fail() { printf '错误：%s\n' "$*" >&2; exit 1; }
trap 'printf "安装失败（第 %s 行）。已完成的包或软件源修改不会自动回滚。\n" "$LINENO" >&2' ERR

[[ $# -eq 0 ]] || fail '本脚本不接受参数。'
[[ $(uname -s) == Linux ]] || fail '仅支持 Linux。'
[[ -r /etc/os-release ]] || fail '无法识别系统。'
. /etc/os-release
major=${VERSION_ID%%.*}
[[ $major =~ ^[0-9]+$ ]] || fail '无法识别系统主版本。'
case "$ID" in
    debian) (( major >= 13 )) || fail '需要 Debian 13 或更新版本。'
        codename=${VERSION_CODENAME:-} ;;
    ubuntu) (( major >= 24 )) || fail '需要 Ubuntu 24 或更新版本。'
        codename=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}} ;;
    *) fail '仅支持 Debian 和 Ubuntu。' ;;
esac
[[ $codename =~ ^[a-z]+$ ]] || fail '缺少有效发行版代号。'
[[ $EUID -eq 0 ]] || fail '请使用 root 或 sudo bash 执行。'
[[ -d /run/systemd/system ]] || fail '需要运行 systemd 的服务器。'
command -v apt-get >/dev/null || fail '未找到 APT。'

# 不自动卸载发行版容器运行时，避免影响已有容器或其他服务。
conflicts=$(dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' \
    docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc 2>/dev/null || true)
while read -r package status; do
    [[ $status != installed ]] || fail "已安装冲突包 $package，请先人工核对；不会自动卸载。"
done <<< "$conflicts"

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
arch=$(dpkg --print-architecture)
source_file=/etc/apt/sources.list.d/docker.list
key_file=/etc/apt/keyrings/docker.gpg
printf 'deb [arch=%s signed-by=%s] https://download.docker.com/linux/%s %s stable\n' \
    "$arch" "$key_file" "$ID" "$codename" > "$scratch/docker.list"
if [[ -e $source_file ]]; then
    cmp -s "$scratch/docker.list" "$source_file" || fail "已有不同的 $source_file，请人工核对后再执行。"
fi
for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [[ -f $file && $file != "$source_file" ]] || continue
    if sed '/^[[:space:]]*#/d' "$file" | grep -F 'download.docker.com/linux/' >/dev/null; then
        fail "已有另一份 Docker 源：$file；请先核对重复或不同渠道配置。"
    fi
done

export DEBIAN_FRONTEND=noninteractive
apt_options=(-o DPkg::Lock::Timeout=300 -o Acquire::Retries=3
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
printf '01 系统：%s；架构：%s。安装依赖，不执行全系统升级。\n' "$PRETTY_NAME" "$arch"
apt-get "${apt_options[@]}" -o APT::Update::Error-Mode=any update
apt-get "${apt_options[@]}" --no-remove -y install ca-certificates curl gnupg
curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --connect-timeout 20 --max-time 180 \
    "https://download.docker.com/linux/$ID/gpg" -o "$scratch/docker.asc"
gpg --batch --yes --dearmor -o "$scratch/docker.gpg" "$scratch/docker.asc"
install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d
install -m 0644 "$scratch/docker.gpg" "$key_file"
install -m 0644 "$scratch/docker.list" "$source_file"

printf '02 从官方 stable 签名索引选择最新稳定包，不固定大版本。\n'
chmod 0755 "$scratch"
install -d -m 0755 "$scratch/lists"
official_options=(-o "Dir::Etc::sourcelist=$source_file" -o Dir::Etc::sourceparts=-
    -o "Dir::State::lists=$scratch/lists" -o Dir::State::status=/dev/null
    -o Dir::Etc::preferences=/dev/null -o Dir::Etc::preferencesparts=-)
apt-get "${apt_options[@]}" "${official_options[@]}" -o APT::Update::Error-Mode=any update
packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
versions=()
specs=()
for package in "${packages[@]}"; do
    if ! policy=$(apt-cache "${official_options[@]}" policy "$package"); then
        fail "读取官方源候选版本失败：$package"
    fi
    candidate=$(awk '/Candidate:/ && !found {print $2; found=1}' <<< "$policy")
    [[ $candidate =~ ^([0-9]+:)?[0-9]+\.[0-9]+\.[0-9]+([.+-].*)?$ && ! $candidate =~ (alpha|beta|rc)[.0-9] ]] \
        || fail "无官方稳定候选：$package ${candidate:-无}；请核对发行版和架构是否受官方支持。"
    installed=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)
    if [[ -n $installed ]] && dpkg --compare-versions "$installed" gt "$candidate"; then
        fail "已安装的 $package $installed 高于官方 stable 候选 $candidate，不自动降级。"
    fi
    versions+=("$candidate")
    specs+=("$package=$candidate")
    printf '  %s：%s\n' "$package" "$candidate"
done
# 版本来自本次查询；只在本次下载中使用精确版本，不设置 APT hold 或 pin。
(
    cd "$scratch"
    apt-get "${apt_options[@]}" "${official_options[@]}" download "${specs[@]}"
)
archives=("$scratch"/*.deb)
[[ ${#archives[@]} -eq ${#packages[@]} && -f ${archives[0]} ]] || fail '未取得全部官方安装包。'

printf '03 安装 Docker Engine 和 Compose 插件；已有 Docker 服务可能重启。\n'
apt-get "${apt_options[@]}" -o APT::Update::Error-Mode=any update
apt-get "${apt_options[@]}" --no-remove -y install "${archives[@]}"
for ((i=0; i<${#packages[@]}; i++)); do
    [[ $(dpkg-query -W -f='${Version}' "${packages[i]}") == "${versions[i]}" ]] \
        || fail "安装版本与官方候选不一致：${packages[i]}"
done

printf '04 验证服务、实际 Engine 版本和 Compose 插件。\n'
systemctl enable --now docker
systemctl is-active --quiet docker
systemctl is-enabled --quiet docker
expected_engine=${versions[0]#*:}
expected_engine=${expected_engine%%-*}
actual_engine=$(/usr/bin/docker --host unix:///var/run/docker.sock version --format '{{.Server.Version}}')
[[ $actual_engine == "$expected_engine" ]] || fail "实际 Engine $actual_engine 与安装包 $expected_engine 不一致。"
/usr/bin/docker --version
actual_compose=$(/usr/bin/docker compose version --short)
expected_compose=${versions[4]#*:}
expected_compose=${expected_compose%%-*}
[[ ${actual_compose#v} == "$expected_compose" ]] || fail "实际 Compose $actual_compose 与安装包 $expected_compose 不一致。"
printf 'Docker Compose：%s\n' "$actual_compose"
/usr/bin/docker buildx version
printf '安装完成：Docker 已运行并设置开机启动；使用 docker compose 命令管理项目。\n'
