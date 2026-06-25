#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

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
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(uname -m)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}注意： CentOS 7 无法使用hysteria1/2协议！${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release wget curl unzip tar crontabs socat ca-certificates -y >/dev/null 2>&1
        update-ca-trust force-enable >/dev/null 2>&1
    elif [[ x"${release}" == x"alpine" ]]; then
        apk add wget curl unzip tar socat ca-certificates >/dev/null 2>&1
        update-ca-certificates >/dev/null 2>&1
    elif [[ x"${release}" == x"debian" ]]; then
        apt-get update -y >/dev/null 2>&1
        apt install wget curl unzip tar cron socat ca-certificates -y >/dev/null 2>&1
        update-ca-certificates >/dev/null 2>&1
    elif [[ x"${release}" == x"ubuntu" ]]; then
        apt-get update -y >/dev/null 2>&1
        apt install wget curl unzip tar cron socat -y >/dev/null 2>&1
        apt-get install ca-certificates wget -y >/dev/null 2>&1
        update-ca-certificates >/dev/null 2>&1
    elif [[ x"${release}" == x"arch" ]]; then
        pacman -Sy --noconfirm >/dev/null 2>&1
        pacman -S --noconfirm --needed wget curl unzip tar cron socat >/dev/null 2>&1
        pacman -S --noconfirm --needed ca-certificates wget >/dev/null 2>&1
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /usr/local/NPSc/NPSc ]]; then
        return 2
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(service NPSc status | awk '{print $3}')
        if [[ x"${temp}" == x"started" ]]; then
            return 0
        else
            return 1
        fi
    else
        temp=$(systemctl status NPSc | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
        if [[ x"${temp}" == x"running" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

install_NPSc() {
    if [[ -e /usr/local/NPSc/ ]]; then
        rm -rf /usr/local/NPSc/
    fi

    mkdir /usr/local/NPSc/ -p
    cd /usr/local/NPSc/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/XTBANNY/NPSc/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 NPSc 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 NPSc 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 NPSc 最新版本：${last_version}，开始安装"
        wget --no-check-certificate -N --progress=bar -O /usr/local/NPSc/NPSc-linux.zip https://github.com/XTBANNY/NPSc/releases/download/${last_version}/NPSc-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 NPSc 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/XTBANNY/NPSc/releases/download/${last_version}/NPSc-linux-${arch}.zip"
        echo -e "开始安装 NPSc $1"
        wget --no-check-certificate -N --progress=bar -O /usr/local/NPSc/NPSc-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 NPSc $1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    unzip NPSc-linux.zip
    rm NPSc-linux.zip -f
    chmod +x NPSc
    mkdir /etc/NPSc/ -p
    cp geoip.dat /etc/NPSc/
    cp geosite.dat /etc/NPSc/
    if [[ x"${release}" == x"alpine" ]]; then
        rm /etc/init.d/NPSc -f
        cat <<EOF > /etc/init.d/NPSc
#!/sbin/openrc-run

name="NPSc"
description="NPSc"

command="/usr/local/NPSc/NPSc"
command_args="server"
command_user="root"

pidfile="/run/NPSc.pid"
command_background="yes"

depend() {
        need net
}
EOF
        chmod +x /etc/init.d/NPSc
        rc-update add NPSc default
        echo -e "${green}NPSc ${last_version}${plain} 安装完成，已设置开机自启"
    else
        rm /etc/systemd/system/NPSc.service -f
        cat <<EOF > /etc/systemd/system/NPSc.service
[Unit]
Description=NPSc Service
After=network.target nss-lookup.target
Wants=network.target

[Service]
User=root
Group=root
Type=simple
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
LimitNOFILE=999999
WorkingDirectory=/usr/local/NPSc/
ExecStart=/usr/local/NPSc/NPSc server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl stop NPSc
        systemctl enable NPSc
        echo -e "${green}NPSc ${last_version}${plain} 安装完成，已设置开机自启"
    fi

    if [[ ! -f /etc/NPSc/config.json ]]; then
        cp config.json /etc/NPSc/
        echo -e ""
        echo -e "全新安装，请先参看教程：https://github.com/XTBANNY/NPSc，配置必要的内容"
        first_install=true
    else
        if [[ x"${release}" == x"alpine" ]]; then
            service NPSc start
        else
            systemctl start NPSc
        fi
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}NPSc 重启成功${plain}"
        else
            echo -e "${red}NPSc 可能启动失败，请稍后使用 NPSc log 查看日志信息，若无法启动，则可能更改了配置格式${plain}"
        fi
        first_install=false
    fi

    if [[ ! -f /etc/NPSc/dns.json ]]; then
        cp dns.json /etc/NPSc/
    fi
    if [[ ! -f /etc/NPSc/route.json ]]; then
        cp route.json /etc/NPSc/
    fi
    if [[ ! -f /etc/NPSc/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/NPSc/
    fi
    if [[ ! -f /etc/NPSc/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/NPSc/
    fi
    curl -o /usr/bin/NPSc -Ls https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/NPSc.sh
    chmod +x /usr/bin/NPSc
    if [ ! -L /usr/bin/npsc ]; then
        ln -s /usr/bin/NPSc /usr/bin/npsc
        chmod +x /usr/bin/npsc
    fi
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "NPSc 管理脚本使用方法 (兼容使用NPSc执行，大小写不敏感): "
    echo "------------------------------------------"
    echo "NPSc              - 显示管理菜单 (功能更多)"
    echo "NPSc start        - 启动 NPSc"
    echo "NPSc stop         - 停止 NPSc"
    echo "NPSc restart      - 重启 NPSc"
    echo "NPSc status       - 查看 NPSc 状态"
    echo "NPSc enable       - 设置 NPSc 开机自启"
    echo "NPSc disable      - 取消 NPSc 开机自启"
    echo "NPSc log          - 查看 NPSc 日志"
    echo "NPSc x25519       - 生成 x25519 密钥"
    echo "NPSc generate     - 生成 NPSc 配置文件"
    echo "NPSc update       - 更新 NPSc"
    echo "NPSc update x.x.x - 更新 NPSc 指定版本"
    echo "NPSc install      - 安装 NPSc"
    echo "NPSc uninstall    - 卸载 NPSc"
    echo "NPSc version      - 查看 NPSc 版本"
    echo "------------------------------------------"
    # 首次安装询问是否生成配置文件
    if [[ $first_install == true ]]; then
        echo ""
        echo -e "${green}==========================================${plain}"
        echo -e "${yellow}您为首次安装 NPSc，是否需要自动生成配置文件？${plain}"
        echo -e "${yellow}自动生成的配置文件需要填写以下信息：${plain}"
        echo -e "${yellow}  1. 面板地址（如：https://your-domain.com）${plain}"
        echo -e "${yellow}  2. 面板 API Key（在面板后台获取）${plain}"
        echo -e "${yellow}  3. 节点 ID（在面板后台获取）${plain}"
        echo -e "${yellow}  4. 节点类型（VLESS/VMESS/TROJAN/SHADOWSOCKS 等）${plain}"
        echo -e "${yellow}  5. 是否启用 TLS${plain}"
        echo -e "${yellow}  6. 证书申请方式（DNS/HTTP/自建）${plain}"
        echo -e "${green}==========================================${plain}"
        echo ""
        read -rp "是否自动配置？(y/n，默认n): " if_generate
        if [[ $if_generate == [Yy] ]]; then
            generate_config_file
        fi
    fi
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

check_ipv6_support() {
    if ip -6 addr | grep -q "inet6"; then
        echo "1"
    else
        echo "0"
    fi
}

generate_x25519_key() {
    echo -n "正在生成 x25519 密钥："
    /usr/local/NPSc/NPSc x25519
    echo ""
}

show_NPSc_version() {
    echo -n "NPSc 版本："
    /usr/local/NPSc/NPSc version
    echo ""
}

add_node_config() {
    echo -e "${green}请选择节点核心类型：${plain}"
    echo -e "${green}1. xray${plain}"
    echo -e "${green}2. singbox${plain}"
    echo -e "${green}3. hysteria2${plain}"
    read -rp "请输入：" core_type_input
    case "$core_type_input" in
        1) core="xray"; core_xray=true ;;
        2) core="sing"; core_sing=true ;;
        3) core="hysteria2"; core_hysteria2=true ;;
        *) echo "无效选择"; return ;;
    esac

    echo ""
    read -rp "请输入面板地址（如：https://your-domain.com）：" ApiHost

    echo ""
    read -rp "请输入面板 API Key：" ApiKey

    echo ""
    read -rp "请输入节点 Node ID（数字）：" NodeID
    if [[ ! "$NodeID" =~ ^[0-9]+$ ]]; then
        echo -e "${red}Node ID 必须是数字！${plain}"
        return
    fi

    if [ "$core_hysteria2" = true ] && [ "$core_xray" = false ] && [ "$core_sing" = false ]; then
        NodeType="hysteria2"
    else
        echo -e "${yellow}请选择节点传输协议：${plain}"
        echo -e "${green}1. Shadowsocks${plain}"
        echo -e "${green}2. Vless${plain}"
        echo -e "${green}3. Vmess${plain}"
        if [ "$core_sing" == true ]; then
            echo -e "${green}4. Hysteria${plain}"
            echo -e "${green}5. Hysteria2${plain}"
        fi
        echo -e "${green}6. Trojan${plain}"
        read -rp "请输入：" NodeTypeInput
        case "$NodeTypeInput" in
            1) NodeType="shadowsocks" ;;
            2) NodeType="vless" ;;
            3) NodeType="vmess" ;;
            4) NodeType="hysteria" ;;
            5) NodeType="hysteria2" ;;
            6) NodeType="trojan" ;;
            *) NodeType="vless" ;;
        esac
    fi

    fastopen=true
    if [ "$NodeType" == "vless" ]; then
        read -rp "是否为 reality 节点？(y/n): " isreality
    elif [ "$NodeType" == "hysteria" ] || [ "$NodeType" == "hysteria2" ]; then
        fastopen=false
    fi

    isreality="${isreality:-n}"
    istls="y"
    if [ "$isreality" != "y" ]; then
        read -rp "是否启用 TLS 证书？(y/n): " istls
    fi

    certmode="none"
    certdomain="example.com"
    if [ "$isreality" != "y" ] && [ "$istls" == "y" ]; then
        echo -e "${yellow}请选择证书申请模式：${plain}"
        echo -e "${green}1. http 模式（域名已正确解析）${plain}"
        echo -e "${green}2. dns 模式（需 API 配置）${plain}"
        echo -e "${green}3. self 模式（自签或已有证书）${plain}"
        read -rp "请输入：" certmode
        case "$certmode" in
            1) certmode="http" ;;
            2) certmode="dns" ;;
            3) certmode="self" ;;
        esac
        read -rp "请输入证书域名（如 example.com）：" certdomain
    fi

    ipv6_support=$(check_ipv6_support)
    listen_ip="0.0.0.0"
    if [ "$ipv6_support" -eq 1 ] && [ "$core_sing" = true ]; then
        listen_ip="::"
    fi

    # Write config.json directly
    local config_file="/etc/NPSc/config.json"

    if [ ! -f "$config_file" ]; then
        echo "{" > "$config_file"
    else
        echo "" > "$config_file"
    fi

    if [ "$core" = "hysteria2" ] && [ "$core_hysteria2" = true ]; then
        fastopen=false
        istls="y"
    fi

    local node_obj="
    {
        \"Core\": \"$core\",
        \"ApiHost\": \"$ApiHost\",
        \"ApiKey\": \"$ApiKey\",
        \"NodeID\": $NodeID,
        \"NodeType\": \"$NodeType\",
        \"Timeout\": 30,
        \"ListenIP\": \"$listen_ip\",
        \"SendIP\": \"0.0.0.0\",
        \"DeviceOnlineMinTraffic\": 200,
        \"MinReportTraffic\": 0,
        \"TCPFastOpen\": $fastopen,
        \"EnableProxyProtocol\": false,
        \"EnableUot\": true,
        \"CertConfig\": {
            \"CertMode\": \"$certmode\",
            \"RejectUnknownSni\": false,
            \"CertDomain\": \"$certdomain\",
            \"CertFile\": \"/etc/NPSc/fullchain.cer\",
            \"KeyFile\": \"/etc/NPSc/cert.key\",
            \"Provider\": \"cloudflare\",
            \"DNSEnv\": {}
        }
    }"

    if [ "$core" = "sing" ] && [ "$core_sing" = true ]; then
        node_obj="{
        \"Core\": \"$core\",
        \"ApiHost\": \"$ApiHost\",
        \"ApiKey\": \"$ApiKey\",
        \"NodeID\": $NodeID,
        \"NodeType\": \"$NodeType\",
        \"Timeout\": 30,
        \"ListenIP\": \"$listen_ip\",
        \"SendIP\": \"0.0.0.0\",
        \"DeviceOnlineMinTraffic\": 200,
        \"MinReportTraffic\": 0,
        \"TCPFastOpen\": $fastopen,
        \"SniffEnabled\": true,
        \"CertConfig\": {
            \"CertMode\": \"$certmode\",
            \"RejectUnknownSni\": false,
            \"CertDomain\": \"$certdomain\",
            \"CertFile\": \"/etc/NPSc/fullchain.cer\",
            \"KeyFile\": \"/etc/NPSc/cert.key\",
            \"Provider\": \"cloudflare\",
            \"DNSEnv\": {}
        }
    }"
    fi

    cat >> "$config_file" <<NODEEOF
"$node_obj"
NODEEOF
}

generate_config_file() {
    echo -e "${yellow}NPSc 配置文件生成向导${plain}"
    echo -e "${red}注意：生成的配置文件会保存到 /etc/NPSc/config.json${plain}"
    echo ""

    nodes_config="[]"

    while true; do
        add_node_config
        echo ""
        read -rp "是否继续添加节点配置？(回车继续，输入 n 退出): " continue_adding
        if [[ "$continue_adding" =~ ^[Nn][Oo]? ]]; then
            break
        fi
    done

    echo -e "${green}配置文件生成完成！${plain}"
    echo -e "${yellow}请编辑 /etc/NPSc/config.json 检查配置${plain}"
    echo ""
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
    echo -e "${green}已放行所有网络端口！${plain}"
}

show_usage() {
    echo "NPSc 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "NPSc              - 显示管理菜单 (功能更多)"
    echo "NPSc start        - 启动 NPSc"
    echo "NPSc stop         - 停止 NPSc"
    echo "NPSc restart      - 重启 NPSc"
    echo "NPSc status       - 查看 NPSc 状态"
    echo "NPSc enable       - 设置 NPSc 开机自启"
    echo "NPSc disable      - 取消 NPSc 开机自启"
    echo "NPSc log          - 查看 NPSc 日志"
    echo "NPSc x25519       - 生成 x25519 密钥"
    echo "NPSc generate     - 生成 NPSc 配置文件"
    echo "NPSc update       - 更新 NPSc"
    echo "NPSc update x.x.x - 安装 NPSc 指定版本"
    echo "NPSc install      - 安装 NPSc"
    echo "NPSc uninstall    - 卸载 NPSc"
    echo "NPSc version      - 查看 NPSc 版本"
    echo "------------------------------------------"
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}NPSc已运行，无需再次启动${plain}"
    else
        if [[ x"${release}" == x"alpine" ]]; then
            service NPSc start
        else
            systemctl start NPSc
        fi
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}NPSc 启动成功${plain}"
        else
            echo -e "${red}NPSc 启动失败，请使用 NPSc log 查看日志${plain}"
        fi
    fi
}

stop() {
    if [[ x"${release}" == x"alpine" ]]; then
        service NPSc stop
    else
        systemctl stop NPSc
    fi
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}NPSc 停止成功${plain}"
    else
        echo -e "${red}NPSc 停止失败${plain}"
    fi
}

restart() {
    if [[ x"${release}" == x"alpine" ]]; then
        service NPSc restart
    else
        systemctl restart NPSc
    fi
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}NPSc 重启成功${plain}"
    else
        echo -e "${red}NPSc 重启失败，请使用 NPSc log 查看日志${plain}"
    fi
}

status_cmd() {
    if [[ x"${release}" == x"alpine" ]]; then
        service NPSc status
    else
        systemctl status NPSc --no-pager -l
    fi
}

enable_svc() {
    if [[ x"${release}" == x"alpine" ]]; then
        rc-update add NPSc
    else
        systemctl enable NPSc
    fi
    echo -e "${green}NPSc 已设置开机自启${plain}"
}

disable_svc() {
    if [[ x"${release}" == x"alpine" ]]; then
        rc-update del NPSc
    else
        systemctl disable NPSc
    fi
    echo -e "${green}NPSc 已取消开机自启${plain}"
}

show_log() {
    if [[ x"${release}" == x"alpine" ]]; then
        echo -e "${red}alpine 系统暂不支持日志查看${plain}"
        exit 1
    else
        journalctl -u NPSc.service -e --no-pager -f
    fi
}

uninstall_npsc() {
    confirm "确定要卸载 NPSc 吗? 所有配置文件将被删除" "n"
    if [[ $? != 0 ]]; then
        return 0
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        service NPSc stop
        rc-update del NPSc
        rm /etc/init.d/NPSc -f
    else
        systemctl stop NPSc
        systemctl disable NPSc
        rm /etc/systemd/system/NPSc.service -f
        systemctl daemon-reload
        systemctl reset-failed
    fi
    rm /etc/NPSc/ -rf
    rm /usr/local/NPSc/ -rf
    echo -e "${green}NPSc 卸载完成${plain}"
}

# 0: running, 1: not running, 2: not installed
check_status_menu() {
    if [[ ! -f /usr/local/NPSc/NPSc ]]; then
        return 2
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(service NPSc status | awk '{print $3}')
        if [[ x"${temp}" == x"started" ]]; then
            return 0
        else
            return 1
        fi
    else
        temp=$(systemctl status NPSc | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
        if [[ x"${temp}" == x"running" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

show_status_menu() {
    check_status_menu
    case $? in
        0) echo -e "NPSc 状态: ${green}已运行${plain}" ;;
        1) echo -e "NPSc 状态: ${yellow}未运行${plain}" ;;
        2) echo -e "NPSc 状态: ${red}未安装${plain}" ;;
    esac
}

update_shell() {
    wget -O /usr/bin/NPSc -N --no-check-certificate https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/NPSc.sh
    if [[ $? != 0 ]]; then
        echo -e "${red}下载脚本失败，请检查本机能否连接 Github${plain}"
    else
        chmod +x /usr/bin/NPSc
        echo -e "${green}脚本更新成功，请重新运行${plain}"
    fi
}

update_npsc() {
    local version="${1:-}"
    if [[ -z "$version" ]]; then
        read -rp "请输入版本号（留空为最新版）：" version
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/install.sh) "${version}"
}

show_menu() {
    echo -e "
  ${green}NPSc 管理脚本${plain}
--- https://github.com/XTBANNY/NPSc ---
  ${green}0. 修改配置${plain}
————————————————
  ${green}1. 安装 NPSc${plain}
  ${green}2. 更新 NPSc${plain}
  ${green}3. 卸载 NPSc${plain}
————————————————
  ${green}4. 启动 NPSc${plain}
  ${green}5. 停止 NPSc${plain}
  ${green}6. 重启 NPSc${plain}
  ${green}7. 查看 NPSc 状态${plain}
  ${green}8. 查看 NPSc 日志${plain}
————————————————
  ${green}9. 设置开机自启${plain}
  ${green}10. 取消开机自启${plain}
————————————————
  ${green}11. 生成配置文件${plain}
  ${green}12. 查看版本信息${plain}
  ${green}13. 生成 X25519 密钥${plain}
  ${green}14. 更新管理脚本${plain}
  ${green}15. 放行所有端口${plain}
  ${green}16. 退出脚本${plain}
 "
    show_status_menu
    echo && read -rp "请输入选择 [0-16]: " num

    case "${num}" in
        0) echo "请手动编辑 /etc/NPSc/config.json"; echo "编辑完成后请运行 NPSc restart";;
        1) install_NPSc ;;
        2) update_npsc ;;
        3) check_status_menu && uninstall_npsc ;;
        4) check_status_menu && start ;;
        5) check_status_menu && stop ;;
        6) check_status_menu && restart ;;
        7) check_status_menu && status_cmd ;;
        8) check_status_menu && show_log ;;
        9) check_status_menu && enable_svc ;;
        10) check_status_menu && disable_svc ;;
        11) generate_config_file ;;
        12) check_status_menu && show_NPSc_version ;;
        13) check_status_menu && generate_x25519_key ;;
        14) update_shell ;;
        15) open_ports ;;
        16) exit ;;
        *) echo -e "${red}请输入正确的数字 [0-16]${plain}" ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
        "start") check_status_menu && start ;;
        "stop") check_status_menu && stop ;;
        "restart") check_status_menu && restart ;;
        "status") check_status_menu && status_cmd ;;
        "enable") check_status_menu && enable_svc ;;
        "disable") check_status_menu && disable_svc ;;
        "log") check_status_menu && show_log ;;
        "update") check_status_menu && update_npsc $2 ;;
        "generate") generate_config_file ;;
        "install") install_NPSc ;;
        "uninstall") check_status_menu && uninstall_npsc ;;
        "x25519") check_status_menu && generate_x25519_key ;;
        "version") check_status_menu && show_NPSc_version ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi
