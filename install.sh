#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

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
[[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]] && arch="64"
[[ $arch == "aarch64" || $arch == "arm64" ]] && arch="arm64-v8a"
[[ $arch == armv7* || $arch == armv8* ]] && arch="arm32-v7a"
echo "架构: ${arch}"

[[ "$(getconf WORD_BIT)" != '32' && "$(getconf LONG_BIT)" != '64' ]] && echo "不支持32位系统" && exit 2

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
    rm -rf /usr/local/NPSc/
    mkdir -p /usr/local/NPSc/ /etc/NPSc/
    cd /usr/local/NPSc/

    last_version=$(curl -Ls --connect-timeout 10 "https://api.github.com/repos/XTBANNY/NPSc/releases/latest" | awk -F'"' '/tag_name/{print $4}')
    if [[ -z "$last_version" ]]; then
        echo -e "${red}无法获取 NPSc 版本信息，请检查网络连接${plain}"
        echo -e "${yellow}请手动编译: git clone https://github.com/XTBANNY/NPSc && cd NPSc && go build${plain}"
        exit 1
    fi

    echo -e "检测到 NPSc ${green}${last_version}${plain}，开始安装"
    download_url="https://github.com/XTBANNY/NPSc/releases/download/${last_version}/NPSc-linux-${arch}.zip"
    wget --no-check-certificate -N --progress=bar -O NPSc-linux.zip "${download_url}" || {
        echo -e "${red}下载 NPSc 失败: ${download_url}${plain}"
        exit 1
    }

    unzip -o NPSc-linux.zip
    rm NPSc-linux.zip -f

    # Extract files from nested directory (zip contains NPSc/NPSc, NPSc/*.json, NPSc/*.dat)
    # Must copy binary to temp name first because ./NPSc is an existing dir
    SrcDir=""
    for d in NPSc NPSc-build/NPSc NPSc-pkg; do
        if [[ -d "$d" ]]; then
            SrcDir="$d"
            break
        fi
    done

    if [[ -n "$SrcDir" ]]; then
        # Copy binary to temp name (cp to ./NPSc would go into the dir, not replace it)
        cp "$SrcDir"/NPSc ./NPSc.bin 2>/dev/null
        cp "$SrcDir"/*.json ./ 2>/dev/null
        cp "$SrcDir"/*.dat ./ 2>/dev/null
        cp "$SrcDir"/*.db ./ 2>/dev/null
        rm -rf "$SrcDir" NPSc-build NPSc-pkg 2>/dev/null
        # Move temp binary to final name
        mv NPSc.bin NPSc 2>/dev/null || { rm -rf NPSc; mv NPSc.bin NPSc 2>/dev/null; }
    fi

    chmod +x NPSc
    cp *.json /etc/NPSc/ 2>/dev/null
    cp *.dat /etc/NPSc/ 2>/dev/null
    cp *.db /etc/NPSc/ 2>/dev/null

    # Create sing_origin.json if not present (required by sing core)
    if [ ! -f /etc/NPSc/sing_origin.json ]; then
        cat > /etc/NPSc/sing_origin.json << 'SINGEOF'
{
  "dns": { "servers": [{"tag": "cf", "address": "1.1.1.1"}], "strategy": "ipv4_only" },
  "outbounds": [
    {"tag": "direct", "type": "direct"},
    {"type": "block", "tag": "block"}
  ],
  "route": {
    "rules": [
      {"ip_is_private": true, "outbound": "block"},
      {"outbound": "direct", "network": ["udp","tcp"]}
    ]
  }
}
SINGEOF
    fi

    # Systemd service
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
depend() { need net; }
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
LimitNOFILE=65535
WorkingDirectory=/etc/NPSc/
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

    echo -e "${green}NPSc ${last_version}${plain} 安装完成，已设置开机自启"

    curl -o /usr/bin/NPSc -Ls https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/NPSc.sh
    chmod +x /usr/bin/NPSc
    [[ ! -L /usr/bin/npsc ]] && { ln -s /usr/bin/NPSc /usr/bin/npsc; chmod +x /usr/bin/npsc; }

    cd $cur_dir
    rm -f install.sh

    echo ""
    echo "NPSc 管理命令: "
    echo "------------------------------------------"
    echo "NPSc              - 显示管理菜单"
    echo "NPSc generate     - 交互式生成配置文件"
    echo "NPSc start        - 启动"
    echo "NPSc stop         - 停止"
    echo "NPSc restart      - 重启"
    echo "NPSc status       - 查看状态"
    echo "NPSc log          - 查看日志"
    echo "------------------------------------------"
    echo ""
    echo -e "${yellow}提示：首次安装请使用 NPSc generate 配置面板信息${plain}"
}

echo -e "${green}开始安装 NPSc...${plain}"
install_base
install_NPSc
