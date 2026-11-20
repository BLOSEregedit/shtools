#!/usr/bin/env bash
# 保留原组合入口；安装逻辑统一在 docker.sh，避免两份实现漂移。
set -Eeuo pipefail
[[ $# -eq 0 ]] || { printf '错误：本脚本不接受参数。\n' >&2; exit 1; }
[[ $(uname -s) == Linux && $EUID -eq 0 ]] \
    || { printf '错误：请在 Linux 上以 root 或 sudo bash 执行。\n' >&2; exit 1; }

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
url=https://raw.githubusercontent.com/BLOSEregedit/shtools/main/basic/docker.sh
if command -v curl >/dev/null; then
    curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --connect-timeout 20 --max-time 180 \
        "$url" -o "$scratch/docker.sh"
elif command -v wget >/dev/null; then
    wget --https-only --timeout=30 --tries=3 -O "$scratch/docker.sh" "$url"
else
    printf '错误：需要 curl 或 wget 下载安装脚本。\n' >&2
    exit 1
fi
bash "$scratch/docker.sh"
