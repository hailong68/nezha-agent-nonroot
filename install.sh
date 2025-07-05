#!/bin/bash

set -e

# Maintained by: hailong68 / GitHub
# Description: 安全部署哪吒监控客户端，非 root 用户运行

# 默认参数
NZ_USER="nezha"
NZ_DIR="/opt/nezha"
NZ_BIN="$NZ_DIR/nezha-agent"
SERVICE_FILE="/etc/systemd/system/nezha-agent.service"

# 从命令行读取参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --server) NZ_SERVER="$2"; shift ;;
        --secret) NZ_SECRET="$2"; shift ;;
        --tls) NZ_TLS="true" ;;
    esac
    shift
done

if [[ -z "$NZ_SERVER" || -z "$NZ_SECRET" ]]; then
    echo "❌ 缺少参数 --server 或 --secret"
    echo "✅ 示例: bash install.sh --server xxx.com:443 --secret xxx --tls"
    exit 1
fi

# 创建非 root 用户（如不存在）
if ! id "$NZ_USER" &>/dev/null; then
    echo "[+] 创建系统用户 $NZ_USER..."
    useradd -r -s /usr/sbin/nologin "$NZ_USER"
fi

# 创建安装目录
mkdir -p "$NZ_DIR"

# 下载 nezha-agent
echo "[+] 下载 nezha-agent 二进制..."
curl -L https://github.com/naiba/nezha/releases/latest/download/nezha-agent_linux_amd64 -o "$NZ_BIN"
chmod +x "$NZ_BIN"
chown -R $NZ_USER:$NZ_USER "$NZ_DIR"

# 写入 systemd 服务
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Nezha Monitoring Agent (Non-root)
After=network.target

[Service]
User=$NZ_USER
WorkingDirectory=$NZ_DIR
ExecStart=$NZ_BIN -s $NZ_SERVER -p $NZ_SECRET $( [[ "$NZ_TLS" == "true" ]] && echo "-tls" )
Restart=always
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
systemctl daemon-reload
systemctl enable --now nezha-agent

echo "✅ 安装完成！可使用以下命令查看状态："
echo "   systemctl status nezha-agent"
echo "   journalctl -u nezha-agent -f"
