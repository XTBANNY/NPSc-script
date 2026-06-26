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
    echo -e "${red}未检测到系统版本！${plain}\n" && exit 1
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
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)"
    exit 2
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

install_NPSc() {
    if [[ -e /usr/local/NPSc/ ]]; then
        rm -rf /usr/local/NPSc/
    fi

    mkdir -p /usr/local/NPSc/ /etc/NPSc/
    cd /usr/local/NPSc/

    # Try NPSc releases first, fall back to V2bX releases
    npsc_release=$(curl -Ls --connect-timeout 5 "https://api.github.com/repos/XTBANNY/NPSc/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -n "$npsc_release" ]]; then
        echo -e "检测到 NPSc 最新版本：${green}${npsc_release}${plain}，开始安装"
        download_url="https://github.com/XTBANNY/NPSc/releases/download/${npsc_release}/NPSc-linux-${arch}.zip"
        wget --no-check-certificate -N --progress=bar -O NPSc-linux.zip "${download_url}" || {
            echo -e "${red}下载 NPSc 失败${plain}"
            exit 1
        }
        unzip -o NPSc-linux.zip
        rm NPSc-linux.zip -f
    else
        # Fallback: use V2bX binary (same codebase)
        echo -e "${yellow}NPSc 没有发布版，使用 V2bX 二进制（同一代码库）${plain}"
        
        v2bx_release=$(curl -Ls --connect-timeout 10 "https://api.github.com/repos/wyx2685/V2bX/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -z "$v2bx_release" ]]; then
            echo -e "${red}无法获取 NPSc 或 V2bX 版本信息，请检查网络连接${plain}"
            exit 1
        fi
        
        echo -e "使用 V2bX ${v2bx_release} 二进制"
        download_url="https://github.com/wyx2685/V2bX/releases/download/${v2bx_release}/V2bX-linux-${arch}.zip"
        wget --no-check-certificate -N --progress=bar -O V2bX-linux.zip "${download_url}" || {
            echo -e "${red}下载 V2bX 失败${plain}"
            exit 1
        }
        unzip -o V2bX-linux.zip
        rm V2bX-linux.zip -f
        # Rename binary from V2bX to NPSc
        mv V2bX NPSc 2>/dev/null || true
    fi

    chmod +x NPSc
    
    # Create symlink to handle hardcoded /etc/V2bX paths in the binary
    ln -sf /etc/NPSc /etc/V2bX
    
    # Copy all config files to /etc/NPSc/
    cp *.json /etc/NPSc/ 2>/dev/null || true
    cp *.dat /etc/NPSc/ 2>/dev/null || true
    cp *.db /etc/NPSc/ 2>/dev/null || true
    
    # Fix any hardcoded paths in config files
    for f in /etc/NPSc/*.json; do
        [ -f "$f" ] && sed -i 's|/etc/V2bX/|/etc/NPSc/|g' "$f" 2>/dev/null
    done

    # Create systemd service with explicit --config flag
    if [[ x"${release}" == x"alpine" ]]; then
        rm /etc/init.d/NPSc -f
        cat <<EOF > /etc/init.d/NPSc
#!/sbin/openrc-run

name="NPSc"
description="NPSc"

command="/usr/local/NPSc/NPSc"
command_args="server --config /etc/NPSc/config.json"
command_user="root"

pidfile="/run/NPSc.pid"
command_background="yes"

depend() {
        need net
}
EOF
        chmod +x /etc/init.d/NPSc
        rc-update add NPSc default
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
ExecStart=/usr/local/NPSc/NPSc server --config /etc/NPSc/config.json
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl stop NPSc 2>/dev/null
        systemctl enable NPSc
    fi

    echo -e "${green}NPSc 安装完成，已设置开机自启${plain}"
    
    # Install management script
    curl -o /usr/bin/NPSc -Ls https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/NPSc.sh
    chmod +x /usr/bin/NPSc
    if [ ! -L /usr/bin/npsc ]; then
        ln -s /usr/bin/NPSc /usr/bin/npsc
        chmod +x /usr/bin/npsc
    fi
    
    cd $cur_dir
    rm -f install.sh
    
    echo -e ""
    echo "NPSc 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "NPSc              - 显示管理菜单"
    echo "NPSc start        - 启动 NPSc"
    echo "NPSc stop         - 停止 NPSc"
    echo "NPSc restart      - 重启 NPSc"
    echo "NPSc status       - 查看 NPSc 状态"
    echo "NPSc log          - 查看 NPSc 日志"
    echo "NPSc enable       - 设置开机自启"
    echo "NPSc disable      - 取消开机自启"
    echo "NPSc generate     - 交互式生成配置文件"
    echo "NPSc update       - 更新 NPSc"
    echo "NPSc uninstall    - 卸载 NPSc"
    echo "------------------------------------------"
}

echo -e "${green}开始安装 NPSc...${plain}"
install_base
install_NPSc
