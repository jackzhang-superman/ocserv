
#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: Debian/Ubuntu
#	Description: Optimized ocserv installer (No SSL generation / No user creation)
#	Version: Custom
#	Author: Jack (Optimized)
#=================================================

sh_ver="optimized"
file="/usr/local/sbin/ocserv"
conf_file="/etc/ocserv"
conf="/etc/ocserv/ocserv.conf"
log_file="/tmp/ocserv.log"
ocserv_ver="1.2.2"
PID_FILE="/var/run/ocserv.pid"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[提示]${Font_color_suffix}"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号，请使用 sudo 权限运行脚本。" && exit 1
}
check_sys(){
	if [[ -f /etc/debian_version ]]; then
		release="debian"
	elif grep -qi ubuntu /etc/issue; then
		release="ubuntu"
	else
		echo -e "${Error} 不支持的系统。" && exit 1
	fi
}
check_installed_status(){
	[[ ! -e ${file} ]] && echo -e "${Error} ocserv 未安装。" && exit 1
	[[ ! -e ${conf} ]] && echo -e "${Error} 配置文件不存在。" && exit 1
}
check_pid(){
	if [[ -e ${PID_FILE} ]]; then
		PID=$(cat ${PID_FILE})
	else
		PID=""
	fi
}
Get_ip(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	[[ -z "${ip}" ]] && ip="VPS_IP"
}

Installation_dependency(){
	[[ ! -e "/dev/net/tun" ]] && echo -e "${Error} VPS 未启用 TUN，请在控制面板开启。" && exit 1
	apt-get update
	apt-get install -y vim net-tools pkg-config build-essential libgnutls28-dev libwrap0-dev \
		liblz4-dev libseccomp-dev libreadline-dev libnl-nf-3-dev libev-dev gnutls-bin
}

Download_ocserv(){
	mkdir -p "ocserv" && cd "ocserv"
	wget "ftp://ftp.infradead.org/pub/ocserv/ocserv-${ocserv_ver}.tar.xz"
	tar -xJf ocserv-${ocserv_ver}.tar.xz && cd ocserv-${ocserv_ver}
	./configure
	make
	make install
	cd ../..
	rm -rf ocserv/
	if [[ ! -e ${file} ]]; then
		echo -e "${Error} ocserv 编译失败。" && exit 1
	fi

	mkdir -p "${conf_file}"
	wget --no-check-certificate -O "${conf_file}/ocserv.conf" \
		"https://raw.githubusercontent.com/jackzhang-superman/ocserv/main/ocserv.conf"
	wget --no-check-certificate -O "${conf_file}/profile.xml" \
		"https://raw.githubusercontent.com/jackzhang-superman/ocserv/main/profile.xml"
}

Service_ocserv(){
	wget --no-check-certificate -O /etc/init.d/ocserv \
		"https://raw.githubusercontent.com/jackzhang-superman/ocserv/main/ocserv_debian"
	chmod +x /etc/init.d/ocserv
	update-rc.d -f ocserv defaults
}

Set_iptables(){
	echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
	sysctl -p
	if command -v ip a >/dev/null 2>&1; then
		if ip a | grep -q "ens3"; then
			Network_card="ens3"
		elif ip a | grep -q "eth0"; then
			Network_card="eth0"
		else
			read -e -p "请输入你的网卡名（如 eth0/ens3/enpXsX）: " Network_card
		fi
	else
		Network_card="eth0"
	fi
	iptables -t nat -A POSTROUTING -o ${Network_card} -j MASQUERADE
	iptables-save > /etc/iptables.up.rules
	echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
	chmod +x /etc/network/if-pre-up.d/iptables
}
Add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 1600 -j ACCEPT
	}
Save_iptables(){
	iptables-save > /etc/iptables.up.rules
}
Start_ocserv(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} ocserv 正在运行。" && exit 1
	/etc/init.d/ocserv start
	sleep 2
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Info} ocserv 启动成功。"
}
Install_ocserv(){
	check_root
	check_sys
	[[ -e ${file} ]] && echo -e "${Error} ocserv 已安装。" && exit 1
	echo -e "${Info} 安装依赖中..."
	Installation_dependency
	echo -e "${Info} 下载并安装 ocserv..."
	Download_ocserv
	echo -e "${Info} 安装服务脚本..."
	Service_ocserv
	echo -e "${Tip} 请手动上传 SSL 证书至 /etc/ocserv/ssl"
	echo -e "${Tip} 请确保 ocserv.conf 中已正确配置 FreeRADIUS"
	echo -e "${Info} 设置 iptables..."
	Set_iptables
	Add_iptables
	Save_iptables
	echo -e "${Info} 启动 ocserv..."
	Start_ocserv
}
Uninstall_ocserv(){
	check_installed_status
	check_pid
	[[ ! -z $PID ]] && kill -9 ${PID} && rm -f ${PID_FILE}
	update-rc.d -f ocserv remove
	rm -rf /etc/init.d/ocserv
	rm -rf "${conf_file}"
	rm -rf "${log_file}"
	rm -f /usr/local/sbin/ocserv
	echo && echo -e "${Info} ocserv 卸载完成。" && echo
}

echo && echo -e " ocserv 一键安装脚本 (精简优化版 v${sh_ver})
  -- 仅适用于 FreeRADIUS 和手动上传证书 --

 ${Green_font_prefix}1.${Font_color_suffix} 安装 ocserv
 ${Green_font_prefix}2.${Font_color_suffix} 卸载 ocserv
————————————" && echo

read -e -p " 请输入数字 [1-2]:" num
case "$num" in
	1)
	Install_ocserv
	;;
	2)
	Uninstall_ocserv
	;;
	*)
	echo "请输入正确数字 [1-2]"
	;;
esac
