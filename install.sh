#!/bin/bash
set -e

# 参数解析
for arg in "$@"; do
  case $arg in
    --server=*) SERVER="${arg#*=}"; shift ;;
    --secret=*) SECRET="${arg#*=}"; shift ;;
    *) echo "❌ 未知参数: $arg"; echo "✅ 示例: bash install.sh --server=xxx:443 --secret=xxx"; exit 1 ;;
  esac
done

if [[ -z "$SERVER" || -z "$SECRET" ]]; then
  echo "❌ 缺少必要参数 --server 或 --secret"
  echo "✅ 示例: bash install.sh --server=xxx:443 --secret=xxx"
  exit 1
fi

# 检查架构
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
  echo "❌ 当前架构为 $ARCH，仅支持 amd64 (x86_64)"
  exit 1
fi

# 创建非 root 用户
NEZHA_USER=nezha
if ! id "$NEZHA_USER" &>/dev/null; then
  echo "[+] 创建系统用户 $NEZHA_USER"
  useradd -r -s /usr/sbin/nologin -m "$NEZHA_USER"
fi

# 安装目录
INSTALL_DIR=/opt/nezha
mkdir -p "$INSTALL_DIR"
chown "$NEZHA_USER":"$NEZHA_USER" "$INSTALL_DIR"

# 下载 agent（二进制）
echo "[+] 下载 nezha-agent (amd64)..."
AGENT_URL="https://github.com/nezhahq/nezha/releases/latest/download/nezha-agent_linux_amd64"
curl -fsSL "$AGENT_URL" -o "$INSTALL_DIR/nezha-agent"
chmod +x "$INSTALL_DIR/nezha-agent"
chown "$NEZHA_USER":"$NEZHA_USER" "$INSTALL_DIR/nezha-agent"

# 验证可执行
if ! "$INSTALL_DIR/nezha-agent" --version &>/dev/null; then
  echo "❌ 下载失败，nezha-agent 不是可执行格式，请检查网络或下载链接"
  exit 1
fi

# systemd 服务
cat >/etc/systemd/system/nezha-agent.service <<EOF
[Unit]
Description=Nezha Monitoring Agent (Non-root, amd64, TLS)
After=network.target

[Service]
Type=simple
User=$NEZHA_USER
ExecStart=$INSTALL_DIR/nezha-agent -s $SERVER -p $SECRET --tls
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable --now nezha-agent

echo "✅ 安装完成！可使用以下命令查看状态："
echo "   systemctl status nezha-agent"
echo "   journalctl -u nezha-agent -f"
