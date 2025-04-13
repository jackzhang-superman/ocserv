#!/bin/bash

# 函数：检查并安装依赖
install_if_missing() {
  for pkg in "$@"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      echo "[INFO] 缺少依赖 $pkg，正在安装..."
      apt install -y "$pkg"
    else
      echo "[OK] 已安装依赖 $pkg"
    fi
  done
}

# 提示用户输入 RADIUS 服务器 IP（用于所有配置）
read -p "请输入 RADIUS 服务器 IP 地址: " RADIUS_IP

# 更新软件源
apt update

# 安装必需依赖（如果缺失）
install_if_missing gcc make wget freeradius-utils

# 下载并解压 freeradius-client 源码
wget ftp://ftp.freeradius.org/pub/freeradius/freeradius-client-1.1.7.tar.gz
tar -zxvf freeradius-client-1.1.7.tar.gz
cd freeradius-client-1.1.7

# 编译安装
./configure
make
make install
cd ~

# 修改 radiusclient.conf 配置文件
CONFIG_FILE="/usr/local/etc/radiusclient/radiusclient.conf"
if [ -f "$CONFIG_FILE" ]; then
  sed -i "s/^authserver.*/authserver\t$RADIUS_IP/" "$CONFIG_FILE"
  sed -i "s/^acctserver.*/acctserver\t$RADIUS_IP/" "$CONFIG_FILE"
  echo "✅ 已设置 authserver 和 acctserver 为 $RADIUS_IP"
else
  echo "⚠️ 配置文件 $CONFIG_FILE 未找到，可能安装失败或路径不同"
fi

# 修改 servers 文件，添加 IP 和共享密钥
SERVERS_FILE="/usr/local/etc/radiusclient/servers"
if [ -f "$SERVERS_FILE" ]; then
  echo -e "$RADIUS_IP\t\ttesting123" >> "$SERVERS_FILE"
  echo "✅ 已将 $RADIUS_IP 添加至 $SERVERS_FILE"
else
  echo "⚠️ servers 文件 $SERVERS_FILE 未找到，可能安装失败或路径不同"
fi

echo -e "\n🎉 FreeRADIUS Client 安装并配置完成！"
