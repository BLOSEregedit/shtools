#!/usr/bin/env bash
# 仅模拟 apt-cache，不执行安装或修改系统。
set -Eeuo pipefail
cd "$(dirname "$0")/.."
query=$(sed -n '/^if ! policy=/,/^candidate=/p' basic/caddy.sh)
[[ -n $query ]]

apt-cache() {
    case "$scenario" in
        large)
            printf '  Candidate: 2.11.4\n'
            for ((i=0; i<10000; i++)); do printf '     2.10.0 500 https://example.invalid repository metadata\n'; done
            ;;
        failed) printf '模拟 APT 查询失败\n' >&2; return 100 ;;
        none) printf '  Candidate: (none)\n' ;;
        empty) printf 'caddy:\n' ;;
    esac
}
fail() { printf '%s\n' "$*" >&2; exit 1; }
official_options=(-o Dir::Etc::sourceparts=-)
scenario=large
eval "$query"
[[ $candidate == 2.11.4 ]]
printf 'PASS：大输出完整读取，版本解析成功。\n'
scenario=failed
if (eval "$query"); then
    fail '查询失败被错误地忽略。'
fi
printf 'PASS：APT 查询失败仍返回失败。\n'
scenario=none
eval "$query"
[[ $candidate == '(none)' ]]
[[ ${candidate#*:} != 2.* ]]
scenario=empty
eval "$query"
[[ -z $candidate ]]
printf 'PASS：无候选及空输出不会被识别为 Caddy 2。\n'
