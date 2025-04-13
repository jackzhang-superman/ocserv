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
	
# 封禁常见高风险端口，防止邮件滥发和 BT 下载
iptables -A FORWARD -o vpns+ -p tcp --dport 25 -j DROP
iptables -A FORWARD -o vpns+ -p tcp --dport 465 -j DROP
iptables -A FORWARD -o vpns+ -p tcp --dport 587 -j DROP
iptables -A FORWARD -o vpns+ -p tcp --dport 6881:6889 -j DROP
iptables -A FORWARD -o vpns+ -p udp --dport 6881:6889 -j DROP
iptables -A FORWARD -o vpns+ -p tcp --dport 6346 -j DROP
iptables -A FORWARD -o vpns+ -p udp --dport 6346 -j DROP
iptables -A FORWARD -o vpns+ -p tcp --dport 990 -j DROP
iptables -A FORWARD -o vpns+ -p tcp --dport 110 -j DROP

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
# 优化文件句柄限制，避免大量连接导致资源耗尽
echo "* soft nofile 51200" >> /etc/security/limits.conf
echo "* hard nofile 51200" >> /etc/security/limits.conf

ulimit -n 51200


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


echo && echo -e " ocserv 管理脚本（优化增强版）
————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 ocserv
 ${Green_font_prefix}2.${Font_color_suffix} 卸载 ocserv
 ${Green_font_prefix}3.${Font_color_suffix} 添加封禁高危端口规则
————————————" && echo

read -e -p " 请输入数字 [1-3]:" num
case "$num" in
	1)
	Install_ocserv
	;;
	2)
	Uninstall_ocserv
	;;
	3)
	Add_iptables
	Save_iptables
	echo -e "${Info} 已应用封禁规则。"
	;;
	*)
	echo "请输入正确数字 [1-3]"
	;;
esac

Set_ocserv_conf(){
	if [[ ! -f ${conf} ]]; then
		echo -e "${Error} 配置文件不存在: ${conf}"
		exit 1
	fi
	vim ${conf}
	echo -e "${Info} 配置修改完成，请重启 ocserv 以应用更改。"
}

Restart_ocserv(){
	check_installed_status
	check_pid
	if [[ ! -z ${PID} ]]; then
		/etc/init.d/ocserv stop
	fi
	/etc/init.d/ocserv start
	sleep 2
	check_pid
	if [[ ! -z ${PID} ]]; then
		echo -e "${Info} ocserv 重启成功。"
	else
		echo -e "${Error} ocserv 重启失败。"
	fi
}

View_ocserv_log(){
	if [[ ! -f ${log_file} ]]; then
		echo -e "${Error} 日志文件不存在: ${log_file}"
		exit 1
	fi
	echo -e "${Tip} 按 Ctrl+C 可退出日志实时查看"
	tail -f ${log_file}
}


echo && echo -e " ocserv 管理脚本（优化增强版）
————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 ocserv
 ${Green_font_prefix}2.${Font_color_suffix} 卸载 ocserv
 ${Green_font_prefix}3.${Font_color_suffix} 添加封禁高危端口规则
 ${Green_font_prefix}4.${Font_color_suffix} 修改 ocserv 配置文件
 ${Green_font_prefix}5.${Font_color_suffix} 重启 ocserv
 ${Green_font_prefix}6.${Font_color_suffix} 查看 ocserv 日志
————————————" && echo

read -e -p " 请输入数字 [1-6]:" num
case "$num" in
	1)
	Install_ocserv
	;;
	2)
	Uninstall_ocserv
	;;
	3)
	Add_iptables
	Save_iptables
	echo -e "${Info} 已应用封禁规则。"
	;;
	4)
	Set_ocserv_conf
	;;
	5)
	Restart_ocserv
	;;
	6)
	View_ocserv_log
	;;
	*)
	echo "请输入正确数字 [1-6]"
	;;
esac

View_ocserv_config(){
	check_installed_status
	Get_ip
	tcp_port=$(grep '^tcp-port' ${conf} | awk -F ' = ' '{print $2}')
	auth_method=$(grep '^auth =' ${conf} | awk -F ' = ' '{print $2}')
	echo && echo -e " ocserv 配置信息预览"
	echo -e "———————————————"
	echo -e " 服务器 IP      : ${Green_font_prefix}${ip}${Font_color_suffix}"
	echo -e " TCP 端口       : ${Green_font_prefix}${tcp_port}${Font_color_suffix}"
	echo -e " 认证方式       : ${Green_font_prefix}${auth_method}${Font_color_suffix}"
	echo -e " 配置文件路径   : ${conf}"
	echo -e "———————————————" && echo
}


echo && echo -e " ocserv 管理脚本（优化增强版）
————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 ocserv
 ${Green_font_prefix}2.${Font_color_suffix} 卸载 ocserv
 ${Green_font_prefix}3.${Font_color_suffix} 添加封禁高危端口规则
 ${Green_font_prefix}4.${Font_color_suffix} 修改 ocserv 配置文件
 ${Green_font_prefix}5.${Font_color_suffix} 重启 ocserv
 ${Green_font_prefix}6.${Font_color_suffix} 查看 ocserv 日志
 ${Green_font_prefix}7.${Font_color_suffix} 查看 ocserv 配置信息
————————————" && echo

read -e -p " 请输入数字 [1-7]:" num
case "$num" in
	1)
	Install_ocserv
	;;
	2)
	Uninstall_ocserv
	;;
	3)
	Add_iptables
	Save_iptables
	echo -e "${Info} 已应用封禁规则。"
	;;
	4)
	Set_ocserv_conf
	;;
	5)
	Restart_ocserv
	;;
	6)
	View_ocserv_log
	;;
	7)
	View_ocserv_config
	;;
	*)
	echo "请输入正确数字 [1-7]"
	;;
esac
