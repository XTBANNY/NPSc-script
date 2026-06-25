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
            echo -e "${red}检测 NPSc 版本失败，请稍后再试，或手动指定版本${plain}"
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
    cp geoip.dat /etc/NPSc/ 2>/dev/null || true
    cp geosite.dat /etc/NPSc/ 2>/dev/null || true
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
            echo -e "${red}NPSc 可能启动失败，请稍后使用 NPSc log 查看日志信息${plain}"
        fi
    fi

    if [[ ! -f /etc/NPSc/dns.json ]]; then
        cp dns.json /etc/NPSc/ 2>/dev/null || true
    fi
    if [[ ! -f /etc/NPSc/route.json ]]; then
        cp route.json /etc/NPSc/ 2>/dev/null || true
    fi
    if [[ ! -f /etc/NPSc/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/NPSc/ 2>/dev/null || true
    fi
    if [[ ! -f /etc/NPSc/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/NPSc/ 2>/dev/null || true
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
    echo "NPSc 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "NPSc              - 显示管理菜单"
    echo "NPSc start        - 启动 NPSc"
    echo "NPSc stop         - 停止 NPSc"
    echo "NPSc restart      - 重启 NPSc"
    echo "NPSc status       - 查看 NPSc 状态"
    echo "NPSc enable       - 设置开机自启"
    echo "NPSc disable      - 取消开机自启"
    echo "NPSc log          - 查看 NPSc 日志"
    echo "NPSc generate     - 生成 NPSc 配置文件"
    echo "NPSc update       - 更新 NPSc"
    echo "NPSc install      - 安装 NPSc"
    echo "NPSc uninstall    - 卸载 NPSc"
    echo "NPSc version      - 查看 NPSc 版本"
    echo "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
install_NPSc $1
