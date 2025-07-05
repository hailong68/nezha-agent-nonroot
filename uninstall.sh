#!/bin/bash

set -e

AGENT_DIR="$HOME/.nezha-agent"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="nezha-agent.service"

# 停止并禁用 systemd 用户服务
if systemctl --user is-active --quiet $SERVICE_NAME; then
    systemctl --user stop $SERVICE_NAME
fi

if systemctl --user is-enabled --quiet $SERVICE_NAME; then
    systemctl --user disable $SERVICE_NAME
fi

# 删除 systemd 服务文件
rm -f "$SYSTEMD_USER_DIR/$SERVICE_NAME"

# 删除 agent 文件和目录
rm -rf "$AGENT_DIR"

# 清除 linger 设置（可选）
if loginctl show-user "$USER" | grep -q "Linger=yes"; then
    sudo loginctl disable-linger "$USER"
fi

echo "✅ Nezha agent (non-root) 已卸载完成。"
