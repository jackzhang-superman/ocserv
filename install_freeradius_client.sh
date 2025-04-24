#!/bin/bash

set -e

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
  echo "❌ 请使用 root 权限运行此脚本（如：sudo bash $0）"
  exit 1
fi

# 函数：检查并安装依赖
install_if_missing() {
  for pkg in "$@"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      echo "[INFO] 正在安装依赖：$pkg ..."
      apt install -y -qq "$pkg"
    else
      echo "[OK] 已安装依赖：$pkg"
    fi
  done
}

# 用户输入 IP
read -rp "请输入 RADIUS 服务器 IP 地址: " RADIUS_IP
if ! [[ $RADIUS_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "❌ 无效的 IP 地址格式：$RADIUS_IP"
  exit 1
fi

echo -e "\n[INFO] 正在更新软件源..."
apt update -y -qq

# 安装所需工具
install_if_missing gcc make wget freeradius-utils libtool autoconf

# 下载源码
echo -e "\n[INFO] 正在下载 FreeRADIUS Client 源码..."
wget -q --show-progress https://github.com/FreeRADIUS/freeradius-client/archive/refs/tags/release_1_1_7.tar.gz -O freeradius-client-1.1.7.tar.gz

# 解压并编译
echo -e "\n[INFO] 解压并开始编译安装..."
tar -zxf freeradius-client-1.1.7.tar.gz
cd freeradius-client-release_1_1_7
./configure
make
make install
cd ~

# 修改配置
CONFIG_DIR="/usr/local/etc/radiusclient"
CONFIG_FILE="$CONFIG_DIR/radiusclient.conf"
SERVERS_FILE="$CONFIG_DIR/servers"

echo -e "\n[INFO] 正在修改配置文件..."
if [[ -f "$CONFIG_FILE" ]]; then
  sed -i "s/^authserver.*/authserver\t$RADIUS_IP/" "$CONFIG_FILE"
  sed -i "s/^acctserver.*/acctserver\t$RADIUS_IP/" "$CONFIG_FILE"
  echo "✅ 配置文件 $CONFIG_FILE 修改完成"
else
  echo "⚠️ 未找到配置文件 $CONFIG_FILE"
fi

if [[ -f "$SERVERS_FILE" ]]; then
  echo -e "$RADIUS_IP\ttesting123" >> "$SERVERS_FILE"
  echo "✅ RADIUS 服务器信息已写入 $SERVERS_FILE"
else
  echo "⚠️ 未找到 servers 文件 $SERVERS_FILE"
fi

# 检查 radtest 是否可用
echo -e "\n[INFO] 检查 radtest 是否可用..."
if command -v radtest >/dev/null; then
  echo "✅ radtest 命令可用，你可以测试认证功能："
  echo "    radtest testuser testpass $RADIUS_IP 0 testing123"
else
  echo "⚠️ radtest 命令未找到，请检查 freeradius-utils 是否正确安装"
fi

echo -e "\n🎉 FreeRADIUS 客户端安装并配置完成！"
