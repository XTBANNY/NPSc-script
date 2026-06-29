#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

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

check_ipv6_support() {
    ip -6 addr | grep -q "inet6" && echo "1" || echo "0"
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
    rm /etc/V2bX -f 2>/dev/null
    rm /usr/local/NPSc/ -rf
    echo -e "${green}NPSc 卸载完成${plain}"
}

# ============================================================
# 配置文件生成向导（支持多节点）
# ============================================================
generate_config() {
    echo -e "${green}==========================================${plain}"
    echo -e "${green}      NPSc 配置文件生成向导${plain}"
    echo -e "${green}==========================================${plain}"
    echo ""

    # 备份旧配置
    if [[ -f /etc/NPSc/config.json ]]; then
        cp /etc/NPSc/config.json /etc/NPSc/config.json.bak
        echo -e "${yellow}已备份旧配置到 config.json.bak${plain}"
    fi

    mkdir -p /etc/NPSc/

    # ── 变量初始化 ──
    core_xray=false
    core_sing=false
    core_hysteria2=false
    nodes_config=()
    node_seq=0
    first_node=true
    fixed_api_info=false
    api_host=""
    api_key=""

    # ── 循环添加多个节点 ──
    while true; do
        node_seq=$((node_seq + 1))
        echo -e "${green}------------------------------------------${plain}"
        echo -e "${green}  添加第 ${node_seq} 个节点${plain}"
        echo -e "${green}------------------------------------------${plain}"

        if [ "$first_node" = true ]; then
            read -rp "面板地址（如 https://example.com）：" api_host
            read -rp "面板对接 API Key：" api_key
            read -rp "是否所有节点使用相同的面板地址和 API Key？(y/n，默认 y): " fixed_input
            fixed_input="${fixed_input:-y}"
            [[ "$fixed_input" == "y" || "$fixed_input" == "Y" ]] && fixed_api_info=true
            first_node=false
        else
            read -rp "是否继续添加节点配置？(回车继续，输入 n 或 no 退出): " continue_adding
            if [[ "$continue_adding" =~ ^[Nn][Oo]?$ ]]; then
                echo -e "${green}节点添加完成${plain}"
                break
            fi
            if [ "$fixed_api_info" = false ]; then
                read -rp "面板地址（如 https://example.com）：" api_host
                read -rp "面板对接 API Key：" api_key
            fi
        fi

        # ── 节点 ID ──
        read -rp "节点 Node ID（数字）：" node_id
        if [[ ! "$node_id" =~ ^[0-9]+$ ]]; then
            echo -e "${red}Node ID 必须是数字！跳过此节点${plain}"
            node_seq=$((node_seq - 1))
            continue
        fi

        # ── 核心类型 ──
        echo ""
        echo -e "${yellow}请选择节点核心类型：${plain}"
        echo -e "${green}1. xray${plain}"
        echo -e "${green}2. singbox${plain}"
        echo -e "${green}3. hysteria2${plain}"
        read -rp "请输入：" core_choice
        case "$core_choice" in
            1) core="xray"; core_xray=true ;;
            2) core="sing"; core_sing=true ;;
            3) core="hysteria2"; core_hysteria2=true ;;
            *) echo -e "${red}无效选择，默认为 singbox${plain}"; core="sing"; core_sing=true ;;
        esac

        # ── 协议选择 ──
        if [[ "$core" == "hysteria2" ]]; then
            NodeType="hysteria2"
        else
            echo ""
            echo -e "${yellow}请选择节点传输协议：${plain}"
            echo -e "${green}1. Shadowsocks${plain}"
            echo -e "${green}2. Vless${plain}"
            echo -e "${green}3. Vmess${plain}"
            echo -e "${green}4. Trojan${plain}"
            if [[ "$core" == "sing" ]]; then
                echo -e "${green}5. Hysteria${plain}"
                echo -e "${green}6. Hysteria2${plain}"
                echo -e "${green}7. Tuic${plain}"
                echo -e "${green}8. AnyTLS${plain}"
            fi
            read -rp "请输入：" NodeTypeInput
            case "$NodeTypeInput" in
                1) NodeType="shadowsocks" ;;
                2) NodeType="vless" ;;
                3) NodeType="vmess" ;;
                4) NodeType="trojan" ;;
                5) NodeType="hysteria" ;;
                6) NodeType="hysteria2" ;;
                7) NodeType="tuic" ;;
                8) NodeType="anytls" ;;
                *) NodeType="vless" ;;
            esac
        fi

        # ── TLS / Reality 配置 ──
        fastopen=true
        if [[ "$NodeType" == "vless" ]]; then
            echo ""
            read -rp "是否为 Reality 节点？(y/n，默认 n): " isreality
            isreality="${isreality:-n}"
        elif [[ "$NodeType" == "hysteria" || "$NodeType" == "hysteria2" || "$NodeType" == "tuic" || "$NodeType" == "anytls" ]]; then
            fastopen=false
            isreality="n"
            istls="y"
        else
            isreality="n"
            istls="n"
        fi

        certmode="none"
        certdomain="example.com"

        if [[ "$isreality" != "y" && "$isreality" != "Y" ]]; then
            if [[ "$NodeType" != "hysteria" && "$NodeType" != "hysteria2" && "$NodeType" != "tuic" && "$NodeType" != "anytls" ]]; then
                echo ""
                read -rp "是否启用 TLS 证书？(y/n，默认 n): " istls
                istls="${istls:-n}"
            fi
        fi

        if [[ "$isreality" != "y" && "$isreality" != "Y" && "$istls" == "y" ]]; then
            echo ""
            echo -e "${yellow}请选择证书申请模式：${plain}"
            echo -e "${green}1. http 模式（域名已正确解析）${plain}"
            echo -e "${green}2. dns 模式（需配置 API 参数）${plain}"
            echo -e "${green}3. self 模式（自签或已有证书文件）${plain}"
            read -rp "请输入：" certmode_input
            case "$certmode_input" in
                1) certmode="http" ;;
                2) certmode="dns" ;;
                3) certmode="self" ;;
                *) certmode="none" ;;
            esac
            read -rp "请输入证书域名（如 example.com）：" certdomain
            if [[ "$certmode" == "dns" ]]; then
                echo -e "${yellow}请安装后手动编辑 /etc/NPSc/config.json 配置 DNS API 参数${plain}"
            fi
        fi

        # ── 监听 IP ──
        ipv6_support=$(check_ipv6_support)
        listen_ip="0.0.0.0"
        if [[ "$ipv6_support" -eq 1 && "$core" == "sing" ]]; then
            listen_ip="::"
        fi

        # ── 生成节点 JSON ──
        node_config="        {
            \"Core\": \"$core\",
            \"ApiHost\": \"$api_host\",
            \"ApiKey\": \"$api_key\",
            \"NodeID\": $node_id,
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
                \"Email\": \"npsc@github.com\",
                \"Provider\": \"cloudflare\",
                \"DNSEnv\": {}
            }
        }"
        nodes_config+=("$node_config")
        echo -e "${green}第 ${node_seq} 个节点添加成功${plain}"
        echo ""
    done

    # 检查是否至少添加了一个节点
    if [[ ${#nodes_config[@]} -eq 0 ]]; then
        echo -e "${red}未添加任何节点，配置生成取消${plain}"
        return 1
    fi

    # ── 写入配置文件 ──
    mkdir -p /etc/NPSc/

    cat > /etc/NPSc/config.json << EOFJSON
{
    "Log": {
        "Level": "error",
        "Output": ""
    },
    "Cores": [
EOFJSON

    local core_count=0
    [[ "$core_xray" == true ]] && core_count=$((core_count + 1))
    [[ "$core_sing" == true ]] && core_count=$((core_count + 1))
    [[ "$core_hysteria2" == true ]] && core_count=$((core_count + 1))
    local core_index=0

    # Xray 核心配置
    if [[ "$core_xray" == true ]]; then
        core_index=$((core_index + 1))
        cat >> /etc/NPSc/config.json << EOFJSON
        {
            "Type": "xray",
            "Log": {
                "Level": "error",
                "ErrorPath": "/etc/NPSc/error.log"
            },
            "OutboundConfigPath": "/etc/NPSc/custom_outbound.json",
            "RouteConfigPath": "/etc/NPSc/route.json"
        }
EOFJSON
        [[ $core_index -lt $core_count ]] && echo "," >> /etc/NPSc/config.json
    fi

    # Sing 核心配置
    if [[ "$core_sing" == true ]]; then
        core_index=$((core_index + 1))
        cat >> /etc/NPSc/config.json << EOFJSON
        {
            "Type": "sing",
            "Log": {
                "Level": "error",
                "Timestamp": true
            },
            "NTP": {
                "Enable": false,
                "Server": "time.apple.com",
                "ServerPort": 0
            },
            "OriginalPath": "/etc/NPSc/sing_origin.json"
        }
EOFJSON
        [[ $core_index -lt $core_count ]] && echo "," >> /etc/NPSc/config.json
    fi

    # Hysteria2 核心配置
    if [[ "$core_hysteria2" == true ]]; then
        core_index=$((core_index + 1))
        cat >> /etc/NPSc/config.json << EOFJSON
        {
            "Type": "hysteria2",
            "Log": {
                "Level": "error"
            }
        }
EOFJSON
        [[ $core_index -lt $core_count ]] && echo "," >> /etc/NPSc/config.json
    fi

    echo "" >> /etc/NPSc/config.json

    # ── 写入 Nodes 数组 ──
    cat >> /etc/NPSc/config.json << EOFJSON
    ],
    "Nodes": [
EOFJSON

    local node_total=${#nodes_config[@]}
    local node_idx=0
    for node in "${nodes_config[@]}"; do
        node_idx=$((node_idx + 1))
        echo "$node" >> /etc/NPSc/config.json
        if [[ $node_idx -lt $node_total ]]; then
            echo "," >> /etc/NPSc/config.json
        fi
    done

    echo "" >> /etc/NPSc/config.json
    echo "    ]" >> /etc/NPSc/config.json
    echo "}" >> /etc/NPSc/config.json

    # ── 创建配套配置文件 ──
    if [[ ! -f /etc/NPSc/custom_outbound.json ]]; then
        cat > /etc/NPSc/custom_outbound.json << 'EOF'
    [
        {
            "tag": "IPv4_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv4v6"
            }
        },
        {
            "tag": "IPv6_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv6"
            }
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
EOF
    fi

    if [[ ! -f /etc/NPSc/route.json ]]; then
        cat > /etc/NPSc/route.json << 'EOF'
    {
        "rules": [
            {
                "type": "field",
                "outboundTag": "block",
                "ip": ["geoip:private"]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "protocol": ["bittorrent"]
            }
        ]
    }
EOF
    fi

    # Always overwrite sing_origin.json to ensure it exists and is valid
    cat > /etc/NPSc/sing_origin.json << 'EOF'
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
EOF

    # ── 完成 ──
    echo ""
    echo -e "${green}==========================================${plain}"
    echo -e "${green}  配置文件已生成！${plain}"
    echo -e "${green}==========================================${plain}"
    echo -e "  主配置: ${yellow}/etc/NPSc/config.json${plain}"
    echo -e "  已添加 ${green}${node_total}${plain} 个节点，共使用了 ${green}${core_count}${plain} 种核心"
    echo ""
    echo -e "  使用 ${green}NPSc restart${plain} 重启服务生效"
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
        0) echo "请手动编辑 /etc/NPSc/config.json，保存后执行 NPSc restart" ;;
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
