#!/bin/sh
# 便捷登录小米路由器 SSH
#   - 兼容新版 OpenSSH（强制协商 ssh-rsa）与老 dropbear
#   - 默认 192.168.31.1 / root，可用环境变量覆盖
#
# 用法:
#   ./ssh-router.sh                 # 进入交互式 shell
#   ./ssh-router.sh 'uname -a'      # 执行一条命令
#   ROUTER_IP=192.168.2.1 ./ssh-router.sh
set -e

ROUTER_IP="${ROUTER_IP:-192.168.31.1}"
ROUTER_USER="${ROUTER_USER:-root}"

exec ssh \
  -o HostKeyAlgorithms=+ssh-rsa \
  -o PubkeyAcceptedAlgorithms=+ssh-rsa \
  -o PubkeyAuthentication=no \
  -o PreferredAuthentications=password \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=10 \
  -o ServerAliveInterval=30 \
  "${ROUTER_USER}@${ROUTER_IP}" "$@"
