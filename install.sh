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

# Create default config files if missing
create_default_configs() {
    local cfgdir="$1"
    mkdir -p "$cfgdir"

    [ ! -f "$cfgdir/config.json" ] && cat > "$cfgdir/config.json" << 'EOF'
{
  "Log": { "Level": "info", "Output": "" },
  "Cores": [{ "Type": "sing", "Log": { "Level": "info", "Timestamp": true }, "NTP": { "Enable": false, "Server": "time.apple.com", "ServerPort": 0 }, "OriginalPath": "/etc/NPSc/sing_origin.json" }],
  "Nodes": [{ "Core": "sing", "ApiHost": "http://127.0.0.1", "ApiKey": "test", "NodeID": 1, "NodeType": "vless", "Timeout": 30, "ListenIP": "0.0.0.0", "SendIP": "0.0.0.0", "DeviceOnlineMinTraffic": 200, "MinReportTraffic": 0, "TCPFastOpen": false, "SniffEnabled": true, "CertConfig": { "CertMode": "none", "RejectUnknownSni": false, "CertDomain": "example.com", "CertFile": "/etc/NPSc/fullchain.cer", "KeyFile": "/etc/NPSc/cert.key", "Provider": "cloudflare", "DNSEnv": { "EnvName": "env1" } } }]
}
EOF

    [ ! -f "$cfgdir/custom_outbound.json" ] && echo '[]' > "$cfgdir/custom_outbound.json"
    [ ! -f "$cfgdir/custom_inbound.json" ] && echo '[]' > "$cfgdir/custom_inbound.json"
    [ ! -f "$cfgdir/dns.json" ] && echo '{}' > "$cfgdir/dns.json"
    [ ! -f "$cfgdir/route.json" ] && echo '{}' > "$cfgdir/route.json"

    if [ ! -f "$cfgdir/sing_origin.json" ]; then
        cat > "$cfgdir/sing_origin.json" << 'SINGEOF'
{
  "dns": {
    "servers": [
      {
        "tag": "cf",
        "address": "1.1.1.1"
      }
    ],
    "strategy": "prefer_ipv4"
  },
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct",
      "domain_resolver": {
        "server": "cf",
        "strategy": "prefer_ipv4"
      }
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "block"
      },
      {
        "domain_regex": [
            "(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
            "(.+.|^)(360|so).(cn|com)",
            "(Subject|HELO|SMTP)",
            "(torrent|.torrent|peer_id=|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=)",
            "(^.@)(guerrillamail|guerrillamailblock|sharklasers|grr|pokemail|spam4|bccto|chacuo|027168).(info|biz|com|de|net|org|me|la)",
            "(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
            "(..||)(dafahao|mingjinglive|botanwang|minghui|dongtaiwang|falunaz|epochtimes|ntdtv|falundafa|falungong|wujieliulan|zhengjian).(org|com|net)",
            "(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)",
            "(.+.|^)(360).(cn|com|net)",
            "(.*.||)(guanjia.qq.com|qqpcmgr|QQPCMGR)",
            "(.*.||)(rising|kingsoft|duba|xindubawukong|jinshanduba).(com|net|org)",
            "(.*.||)(netvigator|torproject).(com|cn|net|org)",
            "(..||)(visa|mycard|gash|beanfun|bank).",
            "(.*.||)(gov|12377|12315|talk.news.pts.org|creaders|zhuichaguoji|efcc.org|cyberpolice|aboluowang|tuidang|epochtimes|zhengjian|110.qq|mingjingnews|inmediahk|xinsheng|breakgfw|chengmingmag|jinpianwang|qi-gong|mhradio|edoors|renminbao|soundofhope|xizang-zhiye|bannedbook|ntdtv|12321|secretchina|dajiyuan|boxun|chinadigitaltimes|dwnews|huaglad|oneplusnews|epochweekly|cn.rfi).(cn|com|org|net|club|net|fr|tw|hk|eu|info|me)",
            "(.*.||)(miaozhen|cnzz|talkingdata|umeng).(cn|com)",
            "(.*.||)(mycard).(com|tw)",
            "(.*.||)(gash).(com|tw)",
            "(.bank.)",
            "(.*.||)(pincong).(rocks)",
            "(.*.||)(taobao).(com)",
            "(.*.||)(laomoe|jiyou|ssss|lolicp|vv1234|0z|4321q|868123|ksweb|mm126).(com|cloud|fun|cn|gs|xyz|cc)",
            "(flows|miaoko).(pages).(dev)"
        ],
        "outbound": "block"
      },
      {
        "outbound": "direct",
        "network": [
          "udp","tcp"
        ]
      }
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true
    }
  }
}
SINGEOF
    fi

    # Try to download geoip/geosite if missing
    if [ ! -f "$cfgdir/geoip.dat" ]; then
        wget -q -O "$cfgdir/geoip.dat" https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat 2>/dev/null || true
    fi
    if [ ! -f "$cfgdir/geosite.dat" ]; then
        wget -q -O "$cfgdir/geosite.dat" https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat 2>/dev/null || true
    fi
}

install_NPSc() {
    rm -rf /usr/local/NPSc/
    mkdir -p /usr/local/NPSc/ /etc/NPSc/
    cd /usr/local/NPSc/

    local last_version=$(curl -Ls --connect-timeout 10 "https://api.github.com/repos/XTBANNY/NPSc/releases/latest" | awk -F'"' '/tag_name/{print $4}')
    if [[ -z "$last_version" ]]; then
        echo -e "${red}无法获取 NPSc 版本信息，请检查网络连接${plain}"
        echo -e "${yellow}请手动编译: git clone https://github.com/XTBANNY/NPSc && cd NPSc && go build${plain}"
        exit 1
    fi

    echo -e "检测到 NPSc ${green}${last_version}${plain}，开始安装"
    local download_url="https://github.com/XTBANNY/NPSc/releases/download/${last_version}/NPSc-linux-${arch}.zip"
    wget --no-check-certificate -N -O NPSc-linux.zip "$download_url" || {
        echo -e "${red}下载 NPSc 失败: ${download_url}${plain}"
        exit 1
    }

    unzip -o NPSc-linux.zip
    rm -f NPSc-linux.zip

    # Handle different zip structures:
    # New format: files at root (NPSc, *.json, *.dat)
    # Old format: nested in NPSc/ directory (NPSc/NPSc, NPSc/*.json, NPSc/*.dat)
    local SrcDir=""
    for d in NPSc NPSc-build/NPSc NPSc-pkg; do
        if [[ -d "$d" ]]; then
            SrcDir="$d"
            break
        fi
    done

    if [[ -n "$SrcDir" ]]; then
        # Copy from nested directory to current dir
        cp "$SrcDir"/NPSc ./NPSc-tmp 2>/dev/null
        cp "$SrcDir"/*.json ./ 2>/dev/null
        cp "$SrcDir"/*.dat ./ 2>/dev/null
        cp "$SrcDir"/*.db ./ 2>/dev/null
        rm -rf "$SrcDir" NPSc-build NPSc-pkg 2>/dev/null
        mv NPSc-tmp NPSc 2>/dev/null
    fi

    # Ensure binary exists and is executable
    chmod +x NPSc 2>/dev/null || { echo -e "${red}NPSc 二进制文件未找到，安装失败${plain}"; exit 1; }

    # Copy config/data files to /etc/NPSc/
    cp -n *.json /etc/NPSc/ 2>/dev/null
    cp -n *.dat /etc/NPSc/ 2>/dev/null
    cp -n *.db /etc/NPSc/ 2>/dev/null

    # Create any missing default config files
    create_default_configs "/etc/NPSc/"

    # Systemd / OpenRC service
    if [[ x"${release}" == x"alpine" ]]; then
        rm -f /etc/init.d/NPSc
        cat <<EOF > /etc/init.d/NPSc
#!/sbin/openrc-run
name="NPSc"
description="NPSc Service"
command="/usr/local/NPSc/NPSc"
command_args="server --config /etc/NPSc/config.json"
command_user="root"
pidfile="/run/NPSc.pid"
command_background="yes"
depend() { need net; }
EOF
        chmod +x /etc/init.d/NPSc
        rc-update add NPSc default 2>/dev/null
    else
        rm -f /etc/systemd/system/NPSc.service
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
        systemctl enable NPSc 2>/dev/null
    fi

    echo -e "${green}NPSc ${last_version}${plain} 安装完成，已设置开机自启"

    curl -o /usr/bin/NPSc -Ls https://raw.githubusercontent.com/XTBANNY/NPSc-script/master/NPSc.sh
    chmod +x /usr/bin/NPSc
    [[ ! -L /usr/bin/npsc ]] && { ln -s /usr/bin/NPSc /usr/bin/npsc; chmod +x /usr/bin/npsc; } 2>/dev/null

    cd "$cur_dir"
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
