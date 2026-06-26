#!/bin/bash

red='[0;31m'
green='[0;32m'
yellow='[0;33m'
plain='[0m'

cur_dir=$(pwd)

[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！
" && exit 1

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
    echo -e "${red}未检测到系统版本！${plain}
" && exit 1
fi

arch=$(uname -m)
[[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]] && arch="64"
[[ $arch == "aarch64" || $arch == "arm64" ]] && arch="arm64-v8a"
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
    rm -f /etc/V2bX
    mkdir -p /usr/local/NPSc/ /etc/NPSc/
    cd /usr/local/NPSc/

    # Get latest NPSc release
    last_version=$(curl -Ls --connect-timeout 10 "https://api.github.com/repos/XTBANNY/NPSc/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*//')
    if [[ -z "$last_version" ]]; then
        echo -e "${red}无法获取 NPSc 版本信息，请检查网络连接${plain}"
        echo -e "${yellow}备用方案：手动安装 Go 并编译
  1. wget https://go.dev/dl/go1.25.0.linux-amd64.tar.gz
  2. tar -C /usr/local -xzf go1.25.0.linux-amd64.tar.gz
  3. export PATH=/usr/local/go/bin:\/c/Users/Banny/.workbuddy/binaries/node/versions/22.22.2:/c/Users/Banny/.workbuddy/binaries/python/versions/3.13.12:/c/Users/Banny/.workbuddy/binaries/node/cli-connector-packages:/c/Users/Banny/bin:/mingw64/bin:/usr/local/bin:/usr/bin:/bin:/mingw64/bin:/usr/bin:/c/Users/Banny/bin:/c/Program Files/Common Files/Oracle/Java/javapath:/d/Software installation/虚拟机/bin:/d/Software installation/影刀:/c/Windows/system32:/c/Windows:/c/Windows/System32/Wbem:/c/Windows/System32/WindowsPowerShell/v1.0:/c/Program Files/cursor/resources/app/bin:/c/Program Files/Git/cmd:/c/Program Files/NVIDIA Corporation/NVIDIA App/NvDLISR:/c/Program Files (x86)/NVIDIA Corporation/PhysX/Common:/c/Users/Banny/AppData/Local/hermes/hermes-agent/venv/Scripts:/c/Users/Banny/AppData/Local/hermes/bin:/d/Software installation/影刀:/c/Users/Banny/AppData/Local/Microsoft/WindowsApps:/c/Users/Banny/AppData/Local/hermes/node:/c/flutter/bin:/c/Program Files/Common Files/Oracle/Java/javapath:/d/Software installation/虚拟机/bin:/d/Software installation/影刀:/c/Windows/system32:/c/Windows:/c/Windows/System32/Wbem:/c/Windows/System32/WindowsPowerShell/v1.0:/c/Program Files/cursor/resources/app/bin:/c/Program Files/Git/cmd:/c/Program Files/NVIDIA Corporation/NVIDIA App/NvDLISR:/c/Program Files (x86)/NVIDIA Corporation/PhysX/Common:/c/Users/Banny/AppData/Local/hermes/hermes-agent/venv/Scripts:/c/Users/Banny/AppData/Local/hermes/bin:/d/Software installation/影刀:/c/Users/Banny/AppData/Local/Microsoft/WindowsApps:/c/Users/Banny/AppData/Local/hermes/node:/c/flutter/bin:/c/Users/Banny/AppData/Local/hermes/hermes-agent/venv/Scripts:/c/Users/Banny/AppData/Local/hermes/bin:/d/Software installation/影刀:/c/Users/Banny/AppData/Local/Microsoft/WindowsApps:/c/Users/Banny/AppData/Local/hermes/node:/c/Users/Banny/AppData/Local/Android/Sdk/platform-tools:/usr/bin/vendor_perl:/usr/bin/core_perl
  4. git clone https://github.com/XTBANNY/NPSc && cd NPSc
  5. GOEXPERIMENT=jsonv2 go build -o NPSc -tags "sing xray hysteria2 with_quic with_grpc with_utls with_wireguard with_acme with_gvisor"
  6. cp NPSc /usr/local/NPSc/${plain}"
        exit 1
    fi

    echo -e "检测到 NPSc ${green}${last_version}${plain}，开始安装"
    download_url="https://github.com/XTBANNY/NPSc/releases/download/${last_version}/NPSc-linux-${arch}.zip"
    wget --no-check-certificate -N --progress=bar -O NPSc-linux.zip "${download_url}" || {
        echo -e "${red}下载 NPSc 失败，请检查网络${plain}"
        exit 1
    }

    unzip -o NPSc-linux.zip
    rm NPSc-linux.zip -f

    # Extract from NPSc subdirectory if it exists
    if [[ -d NPSc ]]; then
        cp NPSc/NPSc ./
        cp NPSc/*.json ./
        cp NPSc/*.dat ./
        cp NPSc/*.db ./
        chmod +x NPSc
    fi

    chmod +x NPSc 2>/dev/null
    cp *.json /etc/NPSc/ 2>/dev/null
    cp *.dat /etc/NPSc/ 2>/dev/null
    cp *.db /etc/NPSc/ 2>/dev/null

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

    echo -e "${green}NPSc ${last_version}${plain} 安装完成，已设置开机自启"

    # Install management script
    curl -o /usr/bin/NPSc -Ls https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/NPSc.sh
    chmod +x /usr/bin/NPSc
    [[ ! -L /usr/bin/npsc ]] && { ln -s /usr/bin/NPSc /usr/bin/npsc; chmod +x /usr/bin/npsc; }

    cd $cur_dir
    rm -f install.sh

    echo ""
    echo "NPSc 管理命令: "
    echo "------------------------------------------"
    echo "NPSc            - 显示管理菜单"
    echo "NPSc generate   - 交互式生成配置文件"
    echo "NPSc start      - 启动"
    echo "NPSc stop       - 停止"
    echo "NPSc restart    - 重启"
    echo "NPSc status     - 查看状态"
    echo "NPSc log        - 查看日志"
    echo "------------------------------------------"
    echo ""
    echo -e "${yellow}提示：首次安装请使用 NPSc generate 配置面板信息${plain}"
}

echo -e "${green}开始安装 NPSc...${plain}"
install_base
install_NPSc
