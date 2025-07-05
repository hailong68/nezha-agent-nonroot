#!/usr/bin/env bash

set -e

# 默认参数
ARCH="amd64"
AGENT_VERSION="nezha-agent_linux_amd64"
GITHUB_REPO="hailong68/nezha-agent-nonroot"
INSTALL_DIR="/opt/nezha"
AGENT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/bin/${AGENT_VERSION}"

# 解析参数
for arg in "$@"; do
  case $arg in
    --server=*)
      SERVER="${arg#*=}"
      ;;
    --secret=*)
      SECRET="${arg#*=}"
      ;;
    --tls)
      TLS="true"
      ;;
    *)
      ;;
  esac
done

# 参数校验
if [[ -z "$SERVER" || -z "$SECRET" ]]; then
  echo "❌ 缺少参数 --server 或 --secret"
  echo "✅ 示例: bash install.sh --server=xxx.com:443 --secret=xxx --tls"
  exit 1
fi

# 创建运行用户
echo "[+] 创建系统用户 nezha..."
id -u nezha &>/dev/null || useradd -r -M -s /sbin/nologin nezha

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 下载 agent
echo "[+] 下载 nezha-agent (amd64)..."
curl -sSL "$AGENT_URL" -o "${INSTALL_DIR}/nezha-agent"
chmod +x "${INSTALL_DIR}/nezha-agent"
chown -R nezha:nezha "$INSTALL_DIR"

# 创建 Systemd 服务文件
cat <<EOF >/etc/systemd/system/nezha-agent.service
[Unit]
Description=Nezha Monitoring Agent (Non-root)
After=network.target

[Service]
User=nezha
ExecStart=${INSTALL_DIR}/nezha-agent -s ${SERVER} -p ${SECRET} --tls
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 重新加载并启动
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now nezha-agent

echo "✅ 安装完成！可使用以下命令查看状态："
echo "   systemctl status nezha-agent"
echo "   journalctl -u nezha-agent -f"
