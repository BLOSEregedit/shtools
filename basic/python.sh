#!/usr/bin/env bash
# uv 官方文档：https://docs.astral.sh/uv/guides/install-python/
# Python 使用 Astral python-build-standalone 预编译发行包，不进行源码编译。
set -Eeuo pipefail
export LC_ALL=C
umask 022
fail() { printf '错误：%s\n' "$*" >&2; exit 1; }
trap 'printf "安装失败（第 %s 行），请检查上方错误。已有修改不会自动回滚。\n" "$LINENO" >&2' ERR

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
[[ $EUID -eq 0 ]] || fail '请使用 root 或 sudo bash 执行。'
[[ -z ${VIRTUAL_ENV:-} && -z ${CONDA_PREFIX:-} ]] || fail '请退出虚拟环境后再安装系统默认命令。'
command -v apt-get >/dev/null || fail '未找到 APT。'
readonly python_root=/opt/shtools-python
readonly bin_dir=/usr/local/bin
# 普通命令由 PATH 选择；不更改 /usr/bin/python3 或用户的 shell 配置。
case ":$PATH:" in *":$bin_dir:"*) ;; *) fail "PATH 不包含 $bin_dir，请先加入该目录。" ;; esac
for name in python python3 uv uvx; do
    [[ ! -d $bin_dir/$name ]] || fail "$bin_dir/$name 是目录，不能替换。"
done

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export DEBIAN_FRONTEND=noninteractive
apt_options=(-o DPkg::Lock::Timeout=300 -o Acquire::Retries=3
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
printf '01 更新索引并安装下载依赖（不执行全系统 upgrade）。\n'
apt-get "${apt_options[@]}" -o APT::Update::Error-Mode=any update
apt-get "${apt_options[@]}" --no-remove -y install ca-certificates curl tar

printf '02 从 Astral 官方渠道获取最新稳定版 uv。\n'
curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --connect-timeout 20 --max-time 180 \
    https://astral.sh/uv/install.sh -o "$scratch/uv-install.sh"
# 隔离已有 UV_*、镜像和项目设置；不写入 root 的 shell 配置。
env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin UV_UNMANAGED_INSTALL="$scratch/uv" \
    sh "$scratch/uv-install.sh"
uv_bin=$scratch/uv/uv
[[ -x $uv_bin && -x $scratch/uv/uvx ]] || fail '未取得 uv 和 uvx 可执行文件。'
"$uv_bin" --version
install -d -m 0755 "$python_root" "$bin_dir"
uv_command=(env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin
    UV_PYTHON_INSTALL_DIR="$python_root" UV_CACHE_DIR="$scratch/cache"
    "$uv_bin" --no-config)

printf '03 选择当前平台可下载的最新普通 CPython 稳定版。\n'
if ! downloads=$("${uv_command[@]}" python list --only-downloads cpython); then
    fail '读取 uv 官方 Python 发行目录失败。'
fi
# 不依赖列表顺序，不把 beta/rc 或 +freethreaded 当作稳定默认版本。
python_version=$(awk '$1 ~ /^cpython-3\.[0-9]+\.[0-9]+-/ {split($1,p,"-"); print p[2]}' <<< "$downloads" \
    | sort -t . -k1,1n -k2,2n -k3,3n | tail -n 1)
[[ $python_version =~ ^3\.[0-9]+\.[0-9]+$ ]] || fail '当前平台没有可用的 CPython 稳定版。'
printf '选定版本：Python %s\n' "$python_version"
"${uv_command[@]}" python install "$python_version" --no-bin
python_bin=$("${uv_command[@]}" python find "$python_version" --managed-python --no-python-downloads --no-project)
[[ $python_bin == "$python_root/"* && -x $python_bin ]] || fail '未找到公共安装目录中的 Python。'
"$python_bin" -I -c 'import sys, ssl, sqlite3, bz2, lzma, ctypes, venv, ensurepip; assert sys.implementation.name == "cpython"; assert sys.version_info.releaselevel == "final"; assert ".".join(map(str,sys.version_info[:3])) == sys.argv[1]' "$python_version"
# 验证非 root 服务用户也能执行；未登录用户使用默认 nobody 账号。
runuser -u nobody -- "$python_bin" --version

printf '04 备份已有入口，并设置默认 Python 命令。\n'
minor_version=${python_version%.*}
names=(python python3 "python$minor_version" uv uvx)
for name in "${names[@]}"; do
    [[ ! -d $bin_dir/$name ]] || fail "$bin_dir/$name 是目录，不能替换。"
done
install -d -m 0700 /var/backups/shtools-python
backup=$(mktemp -d /var/backups/shtools-python/entrypoints.XXXXXXXX)
for name in "${names[@]}"; do
    if [[ -e $bin_dir/$name || -L $bin_dir/$name ]]; then
        cp -a -- "$bin_dir/$name" "$backup/$name"
    else
        printf '%s\n' "$name" >> "$backup/previously-absent.txt"
    fi
done
# 临时文件放在目标文件系统内，通过 rename 替换，避免跟随旧软链接写入。
activation=$(mktemp -d "$bin_dir/.shtools-python.XXXXXXXX")
trap 'rm -rf -- "$scratch" "$activation"' EXIT
install -m 0755 "$uv_bin" "$activation/uv"
install -m 0755 "$scratch/uv/uvx" "$activation/uvx"
for name in python python3 "python$minor_version"; do
    ln -s -- "$python_bin" "$activation/$name"
done
for name in "${names[@]}"; do
    mv -Tf -- "$activation/$name" "$bin_dir/$name"
done
hash -r
[[ $(command -v python) == "$bin_dir/python" && $(command -v python3) == "$bin_dir/python3" ]] \
    || fail "默认命令被 PATH 中更靠前的目录覆盖；请将 $bin_dir 放到前面。备份：$backup"
[[ $(python --version) == "Python $python_version" && $(python3 --version) == "Python $python_version" ]] \
    || fail "默认命令版本验证失败；备份：$backup"
printf '安装完成。Python 来源：Astral python-build-standalone 预编译包。\n'
printf '默认入口：%s/python 和 %s/python3\n解释器：%s\n入口备份：%s\n' "$bin_dir" "$bin_dir" "$python_bin" "$backup"
printf '已保留系统 /usr/bin/python3；已有虚拟环境和服务不会自动切换。\n'
printf '当前终端如缓存了旧路径，请执行 hash -r；下载命令已包含此步骤。\n'
printf '当前安装的 Python 版本：\n'
python --version
python3 --version
