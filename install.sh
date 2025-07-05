#!/usr/bin/env bash

set -e

# ============================
# Nezha Agent Non-Root Install Script (only for amd64)
# ============================

ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
  echo "❌ 当前架构为 $ARCH，仅支持 amd64 (x86_64) 架构安装"
  exit 1
fi

# 检查参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --server=*)
      SERVER="${1#*=}"
      shift
      ;;
    --secret=*)
      SECRET="${1#*=}"
      shift
      ;;
    --tls)
      TLS=true
      shift
      ;;
    *)
      echo "❌ 未知参数: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$SERVER" || -z "$SECRET" ]]; then
  echo "❌ 缺少参数 --server 或 --secret"
  echo "✅ 示例: bash install.sh --server=example.com:443 --secret=YOUR_SECRET --tls"
  exit 1
fi

# 默认开启 TLS
TLS=${TLS:-true}

# 设置变量
AGENT_DIR="$HOME/.nezha-agent"
AGENT_BIN="$AGENT_DIR/nezha-agent"
AGENT_URL="https://raw.githubusercontent.com/hailong68/nezha-agent-nonroot/main/bin/nezha-agent_linux_amd64"

mkdir -p "$AGENT_DIR"
echo "[+] 下载 nezha-agent 到 $AGENT_BIN..."
curl -fsSL "$AGENT_URL" -o "$AGENT_BIN"
chmod +x "$AGENT_BIN"

# 配置 systemd 用户服务
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

cat > "$SYSTEMD_USER_DIR/nezha-agent.service" <<EOF
[Unit]
Description=Nezha Monitoring Agent (Non-root)
After=network.target

[Service]
ExecStart=$AGENT_BIN service run --server $SERVER --secret $SECRET --tls
Restart=always
RestartSec=5s

[Install]
WantedBy=default.target
EOF

# 启用 systemd 用户服务
echo "[+] 启用并启动 systemd 用户服务..."
systemctl --user daemon-reexec || true
systemctl --user daemon-reload
systemctl --user enable --now nezha-agent

# 提示
echo "✅ 安装完成！使用以下命令查看状态："
echo "   systemctl --user status nezha-agent"
echo "   journalctl --user -u nezha-agent -f"
echo "📌 如需开机自启，请确保登录用户已启用 lingering："
echo "   sudo loginctl enable-linger \$USER"
