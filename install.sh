#!/usr/bin/env bash

set -e

# 默认参数
ARCH="amd64"
AGENT_DIR="/opt/nezha"
AGENT_FILE="$AGENT_DIR/nezha-agent"
CONFIG_FILE="$AGENT_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/nezha-agent.service"
USERNAME="nezha"
LOG_CLEANUP_TIMER="/etc/systemd/system/nezha-agent-log-cleanup.timer"
LOG_CLEANUP_SERVICE="/etc/systemd/system/nezha-agent-log-cleanup.service"

# GitHub 地址（使用你自己的仓库）
REPO="hailong68/nezha-agent-nonroot"
AGENT_URL="https://raw.githubusercontent.com/$REPO/main/bin/nezha-agent_linux_amd64"

print_help() {
  echo "用法: bash install.sh --server <服务器地址:端口> --secret <密钥> [--tls]"
  echo "     卸载: bash install.sh --uninstall"
}

if [[ "$1" == "--uninstall" ]]; then
  echo "[+] 正在卸载 nezha-agent..."
  systemctl stop nezha-agent 2>/dev/null || true
  systemctl disable nezha-agent 2>/dev/null || true
  systemctl stop nezha-agent-log-cleanup.timer 2>/dev/null || true
  systemctl disable nezha-agent-log-cleanup.timer 2>/dev/null || true
  rm -f "$SERVICE_FILE" "$LOG_CLEANUP_SERVICE" "$LOG_CLEANUP_TIMER"
  rm -rf "$AGENT_DIR"
  systemctl daemon-reload
  id -u $USERNAME &>/dev/null && userdel -r $USERNAME 2>/dev/null || true
  echo "✅ 卸载完成"
  exit 0
fi

# 检查依赖
command -v curl >/dev/null 2>&1 || { echo >&2 "❌ 未安装 curl"; exit 1; }
command -v systemctl >/dev/null 2>&1 || { echo >&2 "❌ 未安装 systemd"; exit 1; }

# 解析参数
TLS="false"
SERVER=""
SECRET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)
      SERVER="$2"
      shift 2
      ;;
    --secret)
      SECRET="$2"
      shift 2
      ;;
    --tls)
      TLS="true"
      shift
      ;;
    *)
      echo "❌ 未知参数: $1"
      print_help
      exit 1
      ;;
  esac
done

if [[ -z "$SERVER" || -z "$SECRET" ]]; then
  echo "❌ 缺少参数 --server 或 --secret"
  print_help
  exit 1
fi

# 创建用户和目录
echo "[+] 创建系统用户 $USERNAME..."
id -u $USERNAME &>/dev/null || useradd -r -s /bin/false -d $AGENT_DIR $USERNAME
mkdir -p "$AGENT_DIR"
chown $USERNAME:$USERNAME "$AGENT_DIR"

# 下载 agent
echo "[+] 下载 nezha-agent ($ARCH)..."
curl -fsSL "$AGENT_URL" -o "$AGENT_FILE"
chmod +x "$AGENT_FILE"
chown $USERNAME:$USERNAME "$AGENT_FILE"

# 写入配置文件
echo "[+] 写入配置文件..."
cat > "$CONFIG_FILE" <<EOF
server: $SERVER
client_secret: $SECRET
tls: $TLS
disable_auto_update: true
disable_command_execute: true
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 3
self_update_period: 0
skip_connection_count: true
skip_procs_count: true
temperature: false
use_gitee_to_upgrade: false
use_ipv6_country_code: false
EOF
chown $USERNAME:$USERNAME "$CONFIG_FILE"

# 创建 systemd 服务
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Nezha Monitoring Agent (Non-root)
After=network.target

[Service]
Type=simple
User=$USERNAME
ExecStart=$AGENT_FILE -c $CONFIG_FILE
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 创建日志清理服务和定时器（仅清理 nezha-agent 日志）
cat > "$LOG_CLEANUP_SERVICE" <<EOF
[Unit]
Description=Clean Nezha Agent Logs

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/bin/journalctl -u nezha-agent --vacuum-time=7d'
EOF

cat > "$LOG_CLEANUP_TIMER" <<EOF
[Unit]
Description=Weekly Cleanup of Nezha Agent Logs

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 启动服务和定时器
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now nezha-agent
systemctl enable --now nezha-agent-log-cleanup.timer

echo "✅ 安装完成！可使用以下命令查看状态："
echo "   systemctl status nezha-agent"
echo "   journalctl -u nezha-agent -f"
echo "   systemctl list-timers --all | grep nezha"
