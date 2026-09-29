# shtools

服务器脚本合集：`basic/` 为单组件脚本，`oneclick/` 为组合入口，`preHeat/` 与 `scp/` 为专用部署。命令索引见 `wget.txt`，进度和验证边界见 `ROADMAP.md`。

## Caddy 2 官方稳定版

`basic/caddy.sh` 面向使用 systemd 的 Debian 13+、Ubuntu 24+ 服务器，以 root 执行。版本号通过检查不等于该版本已实机验证；系统仓库必须仍能正常更新，官方仓库必须提供当前架构的包。

脚本依次执行：严格检查软件索引更新结果、`apt-get upgrade -y` 常规升级、安装依赖、添加 Caddy 官方 stable 源、从该源下载最新 Caddy 2 包、安装并验证版本、配置及 systemd 状态。保持官方默认目录、运行用户与配置；现有配置文件冲突时保留原文件。官方依据：https://caddyserver.com/docs/install#debian-ubuntu-raspbian 。

在已上传脚本的服务器上执行：

```bash
sudo bash ./basic/caddy.sh
```

GitHub 下载入口见 `wget.txt`。新机器未安装 wget 时，可上传脚本后执行以上命令。

重复执行仍会更新系统，并将 Caddy 更新至官方稳定源最新的 2.x 版本；高于候选版本时不自动降级。系统升级及软件安装可能重启服务，适用于新机器初始化，已有业务的机器需安排维护窗口。脚本不执行发行版升级、不自动重启机器，也不修改站点、防火墙、DNS 或 SSH 配置。

安装失败会返回非零状态；已完成的系统升级不会自动回滚。源不可用、签名失败、架构无包、配置校验失败或服务启动失败时，按输出排查，不会退回系统旧版 Caddy。端口占用也可能导致默认服务启动失败。

## PostgreSQL 17 / 18 官方稳定版

`basic/PG17.sh` 和 `basic/PG18.sh` 是可单独下载执行的脚本，分别安装对应大版本的最新稳定补丁及客户端，固定大版本，不使用跟随新大版本的 `postgresql` 元包。适用系统与权限要求同上；PGDG 必须仍支持实际发行版代号和架构。

```bash
sudo bash ./basic/PG17.sh
# 需要 PostgreSQL 18 的另一台机器使用：
sudo bash ./basic/PG18.sh
```

脚本更新 APT 索引、安装基础依赖、配置 PGDG 官方签名源；从隔离的官方索引下载指定版本的服务端和客户端包，再安装依赖。不会执行全系统 `upgrade`。APT 包安装可能重启已有同大版本数据库，重复执行需安排维护窗口。

默认使用 `main` 集群、端口 `5432`、系统用户 `postgres`，配置位于 `/etc/postgresql/<major>/main/`，数据位于 `/var/lib/postgresql/<major>/main/`。通过 `postgresql.service` 的 auto 集群机制启用开机启动，验证实际集群服务和 SQL 返回的运行版本。不会创建业务账号或数据库、修改认证/远程监听、防火墙或迁移数据。

只用于空机器，或同大版本默认集群的重复安装/补丁更新。检测到另一大版本服务端、跟随大版本的元包、非默认集群/端口或冲突的 PGDG 源时停止；不删除集群、不跨大版本升级、不自动降级。不要在同一台机器上依次执行两个脚本。源不可用、签名或依赖失败时中止，不回退到 Debian 自带旧包；已完成的包和源配置修改不会自动回滚。自定义或停止自动启动的集群需要人工处理。

官方依据：https://www.postgresql.org/download/linux/debian/ 。仓库支持和包版本在执行时核对，模拟测试不等于目标系统实机安装验证。

## 本地验证

```bash
bash -n basic/caddy.sh
bash tests/caddy-candidate.sh
bash -n basic/PG17.sh
bash -n basic/PG18.sh
python3 tests/pg-install.py
```

完整安装与开机启动行为需要在对应 Linux 虚拟机验证，不能在开发用 macOS 上运行安装脚本。
