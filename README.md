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

## 本地验证

```bash
bash -n basic/caddy.sh
```

完整安装与开机启动行为需要在对应 Linux 虚拟机验证，不能在开发用 macOS 上运行安装脚本。
