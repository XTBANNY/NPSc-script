#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "arch"; then
    release="arch"
else
    echo -e "${red}未检测到系统版本！${plain}\n" && exit 1
fi

arch=$(uname -m)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
else
    arch="64"
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [默认$2]: " temp
        [[ x"${temp}" == x"" ]] && temp=$2
    else
        read -rp "$1 [y/n]: " temp
    fi
    [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]] && return 0 || return 1
}

check_status() {
    if [[ ! -f /usr/local/NPSc/NPSc ]]; then
        return 2
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(service NPSc status | awk '{print $3}')
        [[ x"${temp}" == x"started" ]] && return 0 || return 1
    else
        temp=$(systemctl status NPSc | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
        [[ x"${temp}" == x"running" ]] && return 0 || return 1
    fi
}

show_status() {
    check_status
    case $? in
        0) echo -e "NPSc状态: ${green}已运行${plain}" ;;
        1) echo -e "NPSc状态: ${yellow}未运行${plain}" ;;
        2) echo -e "NPSc状态: ${red}未安装${plain}" ;;
    esac
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}NPSc已运行，无需再次启动${plain}"
    else
        [[ x"${release}" == x"alpine" ]] && service NPSc start || systemctl start NPSc
        sleep 2
        check_status
        [[ $? == 0 ]] && echo -e "${green}NPSc 启动成功${plain}" || echo -e "${red}NPSc 启动失败，请使用 NPSc log 查看日志${plain}"
    fi
}

stop() {
    [[ x"${release}" == x"alpine" ]] && service NPSc stop || systemctl stop NPSc
    sleep 2
    check_status
    [[ $? == 1 ]] && echo -e "${green}NPSc 停止成功${plain}" || echo -e "${red}NPSc 停止失败${plain}"
}

restart() {
    [[ x"${release}" == x"alpine" ]] && service NPSc restart || systemctl restart NPSc
    sleep 2
    check_status
    [[ $? == 0 ]] && echo -e "${green}NPSc 重启成功${plain}" || echo -e "${red}NPSc 重启失败，请使用 NPSc log 查看日志${plain}"
}

status_cmd() {
    [[ x"${release}" == x"alpine" ]] && service NPSc status || systemctl status NPSc --no-pager -l
}

enable_svc() {
    [[ x"${release}" == x"alpine" ]] && rc-update add NPSc || systemctl enable NPSc
    echo -e "${green}NPSc 已设置开机自启${plain}"
}

disable_svc() {
    [[ x"${release}" == x"alpine" ]] && rc-update del NPSc || systemctl disable NPSc
    echo -e "${green}NPSc 已取消开机自启${plain}"
}

show_log() {
    if [[ x"${release}" == x"alpine" ]]; then
        echo -e "${red}alpine 系统暂不支持日志查看${plain}"
    else
        journalctl -u NPSc.service -e --no-pager -f
    fi
}

show_version() {
    echo -n "NPSc 版本："
    /usr/local/NPSc/NPSc version 2>&1 || echo "未知"
}

generate_x25519() {
    echo -n "正在生成 x25519 密钥："
    /usr/local/NPSc/NPSc x25519 2>&1 || echo "x25519 功能不可用"
}

open_ports() {
    systemctl stop firewalld 2>/dev/null
    systemctl disable firewalld 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    echo -e "${green}已放行所有网络端口${plain}"
}

update_shell() {
    curl -o /usr/bin/NPSc -Ls https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/NPSc.sh
    chmod +x /usr/bin/NPSc
    echo -e "${green}脚本更新成功${plain}"
}

install_npsc() {
    bash <(curl -Ls https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/install.sh)
}

update_npsc() {
    bash <(curl -Ls https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/install.sh)
    echo -e "${green}更新完成${plain}"
}

uninstall_npsc() {
    confirm "确定要卸载 NPSc 吗？所有配置将被删除" "n" || return 0
    [[ x"${release}" == x"alpine" ]] && { service NPSc stop; rc-update del NPSc; rm /etc/init.d/NPSc -f; } || { systemctl stop NPSc; systemctl disable NPSc; rm /etc/systemd/system/NPSc.service -f; systemctl daemon-reload; }
    rm /etc/NPSc/ -rf
    rm /etc/V2bX -f
    rm /usr/local/NPSc/ -rf
    echo -e "${green}NPSc 卸载完成${plain}"
}

generate_config() {
    echo -e "${green}NPSc 配置文件生成向导${plain}"
    echo -e "${yellow}请依次填写以下信息：${plain}"
    echo ""
    
    read -rp "面板地址（如 https://example.com）：" api_host
    read -rp "面板 API Key：" api_key
    read -rp "节点 ID（数字）：" node_id
    
    echo -e "${green}请选择节点核心类型：${plain}"
    echo -e "1. xray (推荐)"
    echo -e "2. singbox"
    echo -e "3. hysteria2"
    read -rp "请输入：" core_choice
    case "$core_choice" in
        1) core_type="xray" ;;
        2) core_type="sing" ;;
        3) core_type="hysteria2" ;;
        *) core_type="xray" ;;
    esac
    
    echo -e "${green}请选择节点协议：${plain}"
    echo -e "1. Vless"
    echo -e "2. Vmess"
    echo -e "3. Trojan"
    echo -e "4. Shadowsocks"
    echo -e "5. Hysteria2"
    read -rp "请输入：" proto_choice
    case "$proto_choice" in
        1) proto="vless" ;;
        2) proto="vmess" ;;
        3) proto="trojan" ;;
        4) proto="shadowsocks" ;;
        5) proto="hysteria2" ;;
        *) proto="vless" ;;
    esac
    
    read -rp "是否启用 TLS？(y/n)：" use_tls
    cert_mode="none"
    cert_domain="example.com"
    if [[ "$use_tls" == "y" || "$use_tls" == "Y" ]]; then
        cert_mode="dns"
        read -rp "证书域名：" cert_domain
    fi
    
    # Write config
    mkdir -p /etc/NPSc/
    if [[ -f /etc/NPSc/config.json ]]; then
        cp /etc/NPSc/config.json /etc/NPSc/config.json.bak
    fi
    
    cat > /etc/NPSc/config.json << EOFJSON
{
  "Log": {
    "Level": "error",
    "Output": ""
  },
  "Cores": [
    {
      "Type": "$core_type",
      "Log": {
        "Level": "error"
      }
    }
  ],
  "Nodes": [
    {
      "Core": "$core_type",
      "ApiHost": "$api_host",
      "ApiKey": "$api_key",
      "NodeID": $node_id,
      "NodeType": "$proto",
      "Timeout": 30,
      "ListenIP": "0.0.0.0",
      "SendIP": "0.0.0.0",
      "DeviceOnlineMinTraffic": 200,
      "MinReportTraffic": 0,
      "CertConfig": {
        "CertMode": "$cert_mode",
        "RejectUnknownSni": false,
        "CertDomain": "$cert_domain",
        "CertFile": "/etc/NPSc/fullchain.cer",
        "KeyFile": "/etc/NPSc/cert.key",
        "Provider": "cloudflare",
        "DNSEnv": {}
      }
    }
  ]
}
EOFJSON

    # Ensure symlink for hardcoded paths
    [[ ! -L /etc/V2bX ]] && ln -sf /etc/NPSc /etc/V2bX 2>/dev/null
    
    echo -e "${green}配置文件已保存到 /etc/NPSc/config.json${plain}"
    echo -e "${yellow}请使用 NPSc restart 重启服务${plain}"
}

show_menu() {
    echo -e "
  ${green}NPSc 管理脚本${plain}
--- https://github.com/XTBANNY/NPSc ---
  ${green}0. 修改配置${plain}
  ${green}1. 生成配置文件${plain}
————————————————
  ${green}2. 安装/重新安装 NPSc${plain}
  ${green}3. 更新 NPSc${plain}
  ${green}4. 卸载 NPSc${plain}
————————————————
  ${green}5. 启动 NPSc${plain}
  ${green}6. 停止 NPSc${plain}
  ${green}7. 重启 NPSc${plain}
  ${green}8. 查看 NPSc 状态${plain}
  ${green}9. 查看 NPSc 日志${plain}
————————————————
  ${green}10. 设置开机自启${plain}
  ${green}11. 取消开机自启${plain}
  ${green}12. 查看版本${plain}
  ${green}13. 生成 X25519 密钥${plain}
  ${green}14. 放行所有端口${plain}
  ${green}15. 更新管理脚本${plain}
  ${green}16. 退出${plain}
 "
    show_status
    echo && read -rp "请输入选择 [0-16]: " num

    case "${num}" in
        0) echo "请手动编辑 /etc/NPSc/config.json，然后运行 NPSc restart" ;;
        1) generate_config ;;
        2) install_npsc ;;
        3) update_npsc ;;
        4) check_status; uninstall_npsc ;;
        5) check_status; start ;;
        6) check_status; stop ;;
        7) check_status; restart ;;
        8) check_status; status_cmd ;;
        9) check_status; show_log ;;
        10) check_status; enable_svc ;;
        11) check_status; disable_svc ;;
        12) check_status; show_version ;;
        13) check_status; generate_x25519 ;;
        14) open_ports ;;
        15) update_shell ;;
        16) exit ;;
        *) echo -e "${red}请输入正确的数字 [0-16]${plain}" ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
        "start") check_status; start ;;
        "stop") check_status; stop ;;
        "restart") check_status; restart ;;
        "status") check_status; status_cmd ;;
        "enable") check_status; enable_svc ;;
        "disable") check_status; disable_svc ;;
        "log") check_status; show_log ;;
        "update") check_status; update_npsc ;;
        "generate") generate_config ;;
        "install") install_npsc ;;
        "uninstall") check_status; uninstall_npsc ;;
        "x25519") check_status; generate_x25519 ;;
        "version") check_status; show_version ;;
        *) show_menu ;;
    esac
else
    show_menu
fi
