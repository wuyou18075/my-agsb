#!/bin/sh
#=======================================================================================
# CSB 交互式管理面板 (v8.0 - 终极重构版)
#
# · 项目地址: github.com/yonggekkk/argosb
# · 原作者: 甬哥
# · 本次重构优化: Gemini
#
# v8.0 修正:
# 1. 【彻底重构】从零开始重写整个安装引擎，采用线性、独立的模块化逻辑，
#    从结构上根除所有 'syntax error' 的可能性。
#=======================================================================================

export LANG=en_US.UTF-8

# --- 全局变量和预设 ---
SERVICE_DIR="/etc/systemd/system"
AGSB_DIR="$HOME/agsb"
BIN_DIR="$HOME/bin"
COMMAND_NAME="csb"

# --- 辅助函数 ---
_echo() {
    printf "%s\n" "$@"
}

_error() {
    printf "错误: %s\n" "$@" >&2
}

_pause() {
    printf "\n按任意键返回主菜单..."
    read -n 1 -s -r
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        _error "此脚本需要以 root 权限运行。请使用 'sudo bash $0' 或切换到 root 用户后执行。"
        exit 1
    fi
}

download_file() {
    _echo "正在下载: $2"
    curl -Lo "$1" -# --retry 2 "$2"
    if [ $? -ne 0 ]; then
        _error "下载文件失败: $2"
        return 1
    fi
    _echo "下载成功。"
    return 0
}

# --- 服务管理与IP处理 ---
stop_and_disable_services() {
    _echo "正在停止并禁用所有相关服务..."
    systemctl stop csb-xray.service csb-singbox.service csb-cloudflared.service >/dev/null 2>&1
    systemctl disable csb-xray.service csb-singbox.service csb-cloudflared.service >/dev/null 2>&1
    pkill -f "csb/(s|x|c)" >/dev/null 2>&1
}

create_systemd_service() {
    local service_name="$1"
    local description="$2"
    local exec_command="$3"
    _echo "正在创建 systemd 服务: $service_name"
    cat > "$SERVICE_DIR/$service_name.service" <<EOF
[Unit]
Description=$description
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$AGSB_DIR
ExecStart=$exec_command
Restart=on-failure
RestartSec=5s
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    if [ $? -ne 0 ]; then
        _error "创建 $service_name.service 文件失败。"
        return 1
    fi
}

get_server_ip() {
    if [ -n "$ipsw" ] && [ "$ipsw" != "4" ] && [ "$ipsw" != "6" ]; then
        _echo "使用用户指定的 IP: $ipsw"
        server_ip="$ipsw"
        if echo "$server_ip" | grep -q ':'; then
            server_ip="[$server_ip]"
        fi
        return
    fi

    if [ "$ipsw" = "6" ]; then
        _echo "正在检测本机 IPv6 地址..."
        v6_ip=$(curl -s6m5 icanhazip.com -k)
        if [ -n "$v6_ip" ]; then
            server_ip="[$v6_ip]"
            _echo "检测到 IPv6 地址: $v6_ip"
        else
            _error "未能检测到有效的 IPv6 地址。"
            exit 1
        fi
        return
    fi

    _echo "正在检测本机 IPv4 地址..."
    v4_ip=$(curl -s4m5 icanhazip.com -k)
    if [ -n "$v4_ip" ]; then
        server_ip="$v4_ip"
        _echo "检测到 IPv4 地址: $v4_ip"
    else
        _error "未能检测到有效的 IPv4 地址。这是生成节点所必需的。"
        exit 1
    fi
}

# --- 核心功能模块 ---
run_installation() {
    clear
    _echo "--- 开始安装/更新 CSB (v8.0 重构版) ---"

    if [ -d "$AGSB_DIR" ]; then
        _echo "检测到现有安装，将执行更新操作..."
        stop_and_disable_services
    fi

    # 1. 初始化变量和环境
    export vlpt=${vlpt:-''}
    export vmpt=${vmpt:-''}
    export hypt=${hypt:-''}
    export tupt=${tupt:-''}
    export xhpt=${xhpt:-''}
    export anpt=${anpt:-''}

    if [ -z "$vlpt" ] && [ -z "$vmpt" ] && [ -z "$hypt" ] && [ -z "$tupt" ] && [ -z "$xhpt" ] && [ -z "$anpt" ]; then
        _echo "提示：未通过环境变量指定任何协议，将默认安装 VMESS-WS + Hysteria2。"
        export vmpt=9315
        export hypt=9316
    fi

    [ -n "$vlpt" ] && vlp=yes || vlp=no
    [ -n "$vmpt" ] && vmp=yes || vmp=no
    [ -n "$hypt" ] && hyp=yes || hyp=no
    [ -n "$tupt" ] && tup=yes || tup=no
    [ -n "$xhpt" ] && xhp=yes || xhp=no
    [ -n "$anpt" ] && anp=yes || anp=no

    export uuid=${uuid:-''}
    export ipsw=${ip:-''}
    export cdn=${cdn:-''}
    export ym_vl_re=${reym:-''}

    hostname=$(uname -a | awk '{print $2}')
    case $(uname -m) in
        aarch64) cpu=arm64 ;;
        x86_64) cpu=amd64 ;;
        *)
            _error "不支持的CPU架构: $(uname -m)"
            return 1
            ;;
    esac

    mkdir -p "$AGSB_DIR"

    if [ -z "$uuid" ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    echo "$uuid" > "$AGSB_DIR/uuid"
    _echo "UUID: $uuid"

    # 2. 判断需要哪些核心程序
    singbox_needed=no
    xray_needed=no

    if [ "$hyp" = "yes" ] || [ "$tup" = "yes" ] || [ "$anp" = "yes" ]; then
        singbox_needed=yes
    fi

    if [ "$vlp" = "yes" ] || [ "$xhp" = "yes" ]; then
        xray_needed=yes
    fi

    if [ "$vmp" = "yes" ]; then
        if [ "$singbox_needed" = "no" ]; then
            xray_needed=yes
        fi
    fi

    # 3. 准备核心程序和配置文件头部
    xray_first_inbound=yes
    singbox_first_inbound=yes

    if [ "$xray_needed" = "yes" ]; then
        _echo "========= 准备 xray 内核 ========="
        if [ ! -e "$AGSB_DIR/xray" ]; then
            download_file "$AGSB_DIR/xray" "https://github.com/yonggekkk/ArgoSB/releases/download/argosbx/xray-$cpu" || return 1
            chmod +x "$AGSB_DIR/xray"
        fi
        echo '{"log":{"access":"/dev/null","error":"/dev/null","loglevel":"none"},"inbounds":[' > "$AGSB_DIR/xr.json"
    fi

    if [ "$singbox_needed" = "yes" ]; then
        _echo "========= 准备 sing-box 内核 ========="
        if [ ! -e "$AGSB_DIR/sing-box" ]; then
            download_file "$AGSB_DIR/sing-box" "https://github.com/yonggekkk/ArgoSB/releases/download/argosbx/sing-box-$cpu" || return 1
            chmod +x "$AGSB_DIR/sing-box"
        fi
        echo '{"log":{"level":"info"},"inbounds":[' > "$AGSB_DIR/sb.json"
        openssl ecparam -genkey -name prime256v1 -out "$AGSB_DIR/private.key" >/dev/null 2>&1
        openssl req -new -x509 -days 36500 -key "$AGSB_DIR/private.key" -out "$AGSB_DIR/cert.pem" -subj "/CN=www.bing.com" >/dev/null 2>&1
    fi

    # 4. 逐个协议判断并附加到配置文件
    # VLESS-Reality
    if [ "$vlp" = "yes" ]; then
        if [ -z "$ym_vl_re" ]; then
            ym_vl_re=www.yahoo.com
        fi
        echo "$ym_vl_re" > "$AGSB_DIR/ym_vl_re"
        _echo "Reality域名: $ym_vl_re"

        mkdir -p "$AGSB_DIR/xrk"
        if [ ! -e "$AGSB_DIR/xrk/private_key" ]; then
            key_pair=$("$AGSB_DIR/xray" x25519)
            p_key=$(echo "$key_pair" | awk 'NR==1{print $3}')
            pub_key=$(echo "$key_pair" | awk 'NR==2{print $3}')
            s_id=$(date +%s%N | sha256sum | head -c 8)
            echo "$p_key" > "$AGSB_DIR/xrk/private_key"
            echo "$pub_key" > "$AGSB_DIR/xrk/public_key"
            echo "$s_id" > "$AGSB_DIR/xrk/short_id"
        fi

        private_key_x=$(cat "$AGSB_DIR/xrk/private_key")
        public_key_x=$(cat "$AGSB_DIR/xrk/public_key")
        short_id_x=$(cat "$AGSB_DIR/xrk/short_id")

        if [ "$xray_first_inbound" = "no" ]; then
            echo "," >> "$AGSB_DIR/xr.json"
        fi
        xray_first_inbound=no

        if [ -z "$port_vl_re" ]; then
            port_vl_re=$(shuf -i 10000-65535 -n 1)
        fi
        echo "$port_vl_re" > "$AGSB_DIR/port_vl_re"
        _echo "Vless-reality-vision端口: $port_vl_re"

        cat >> "$AGSB_DIR/xr.json" <<EOF
{"tag":"reality-vision","listen":"::","port":$port_vl_re,"protocol":"vless","settings":{"clients":[{"id":"${uuid}","flow":"xtls-rprx-vision"}],"decryption":"none"},"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"fingerprint":"chrome","dest":"${ym_vl_re}:443","serverNames":["${ym_vl_re}"],"privateKey":"$private_key_x","shortIds":["$short_id_x"]}},"sniffing":{"enabled":true,"destOverride":["http","tls","quic"]}}
EOF
    fi

    # VLESS-XTLS (示例占位，需补充具体逻辑)
    if [ "$xhp" = "yes" ]; then
        # 这里可以添加 VLESS-XTLS 的配置逻辑
        _echo "VLESS-XTLS 配置尚未实现"
    fi

    # Hysteria2
    if [ "$hyp" = "yes" ]; then
        if [ "$singbox_first_inbound" = "no" ]; then
            echo "," >> "$AGSB_DIR/sb.json"
        fi
        singbox_first_inbound=no

        if [ -z "$port_hy2" ]; then
            port_hy2=$(shuf -i 10000-65535 -n 1)
        fi
        echo "$port_hy2" > "$AGSB_DIR/port_hy2"
        _echo "Hysteria-2端口: $port_hy2"

        cat >> "$AGSB_DIR/sb.json" <<EOF
{"type":"hysteria2","tag":"hy2-sb","listen":"::","listen_port":${port_hy2},"users":[{"password":"${uuid}"}],"tls":{"enabled":true,"alpn":["h3"],"certificate_path":"$AGSB_DIR/cert.pem","key_path":"$AGSB_DIR/private.key"}}
EOF
    fi

    # TUIC
    if [ "$tup" = "yes" ]; then
        if [ "$singbox_first_inbound" = "no" ]; then
            echo "," >> "$AGSB_DIR/sb.json"
        fi
        singbox_first_inbound=no

        if [ -z "$port_tu" ]; then
            port_tu=$(shuf -i 10000-65535 -n 1)
        fi
        echo "$port_tu" > "$AGSB_DIR/port_tu"
        _echo "Tuic端口: $port_tu"

        cat >> "$AGSB_DIR/sb.json" <<EOF
{"type":"tuic","tag":"tuic5-sb","listen":"::","listen_port":${port_tu},"users":[{"uuid":"${uuid}","password":"${uuid}"}],"congestion_control":"bbr","tls":{"enabled":true,"alpn":["h3"],"certificate_path":"$AGSB_DIR/cert.pem","key_path":"$AGSB_DIR/private.key"}}
EOF
    fi

    # Anytls (示例占位，需补充具体逻辑)
    if [ "$anp" = "yes" ]; then
        _echo "Anytls 配置尚未实现"
    fi

    # VMESS
    if [ "$vmp" = "yes" ]; then
        if [ -z "$port_vm_ws" ]; then
            port_vm_ws=$(shuf -i 10000-65535 -n 1)
        fi
        echo "$port_vm_ws" > "$AGSB_DIR/port_vm_ws"
        _echo "Vmess-ws端口: $port_vm_ws"

        if [ "$xray_needed" = "yes" ]; then
            if [ "$xray_first_inbound" = "no" ]; then
                echo "," >> "$AGSB_DIR/xr.json"
            fi
            xray_first_inbound=no

            cat >> "$AGSB_DIR/xr.json" <<EOF
{"tag":"vmess-xr","listen":"::","port":${port_vm_ws},"protocol":"vmess","settings":{"clients":[{"id":"${uuid}"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"/${uuid}-vm"}},"sniffing":{"enabled":true,"destOverride":["http","tls","quic"]}}
EOF
        else
            if [ "$singbox_first_inbound" = "no" ]; then
                echo "," >> "$AGSB_DIR/sb.json"
            fi
            singbox_first_inbound=no

            cat >> "$AGSB_DIR/sb.json" <<EOF
{"type":"vmess","tag":"vmess-sb","listen":"::","listen_port":${port_vm_ws},"users":[{"uuid":"${uuid}"}],"transport":{"type":"ws","path":"/${uuid}-vm"}}
EOF
        fi
    fi

    # 5. 收尾并创建服务
    if [ "$xray_needed" = "yes" ]; then
        echo '],"outbounds":[{"protocol":"freedom","tag":"direct"}]}' >> "$AGSB_DIR/xr.json"
        create_systemd_service "csb-xray" "CSB Xray Service" "$AGSB_DIR/xray run -c $AGSB_DIR/xr.json"
    fi

    if [ "$singbox_needed" = "yes" ]; then
        echo '],"outbounds":[{"type":"direct"}]}' >> "$AGSB_DIR/sb.json"
        create_systemd_service "csb-singbox" "CSB Sing-box Service" "$AGSB_DIR/sing-box run -c $AGSB_DIR/sb.json"
    fi

    _echo "正在启动所有服务..."
    systemctl daemon-reload

    if [ -f "$SERVICE_DIR/csb-xray.service" ]; then
        systemctl enable --now csb-xray.service
    fi

    if [ -f "$SERVICE_DIR/csb-singbox.service" ]; then
        systemctl enable --now csb-singbox.service
    fi

    _echo "正在设置 '$COMMAND_NAME' 快捷命令..."
    mkdir -p "$BIN_DIR"
    cp -- "$0" "$BIN_DIR/$COMMAND_NAME"
    chmod +x "$BIN_DIR/$COMMAND_NAME"

    if ! grep -q "export PATH=\"\$HOME/bin:\$PATH\"" "$HOME/.bashrc"; then
        echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "$HOME/.bashrc"
    fi

    _echo "\n--- 安装/更新完成！正在生成节点信息... ---"
    display_node_info "no_clear"

    if [ -n "$cdn" ]; then
        generate_cdn_nodes
    fi

    _echo "\n==================================================================="
    _echo "重要：安装/更新已完成！"
    _echo "快捷命令 '$COMMAND_NAME' 已成功设置。"
    _echo "如需在当前终端立即使用，请手动执行: source ~/.bashrc"
    _echo "或重新连接SSH即可自动生效。"
    _echo "==================================================================="
}

# --- 显示节点信息 ---
display_node_info() {
    if [ ! -f "$AGSB_DIR/uuid" ]; then
        _error "CSB 尚未安装。"
        return
    fi

    if [ "$1" != "no_clear" ]; then
        clear
    fi

    _echo "--- 当前节点信息 ---"

    ipsw=${ip:-''}
    get_server_ip

    _echo "--- 使用IP: $server_ip ---"

    rm -f "$AGSB_DIR/jh.txt"

    hostname=$(uname -a | awk '{print $2}')
    uuid=$(cat "$AGSB_DIR/uuid")

    if [ -f "$AGSB_DIR/port_xh" ] || [ -f "$AGSB_DIR/port_vl_re" ]; then
        ym_vl_re=$(cat "$AGSB_DIR/ym_vl_re")
        private_key_x=$(cat "$AGSB_DIR/xrk/private_key")
        public_key_x=$(cat "$AGSB_DIR/xrk/public_key")
        short_id_x=$(cat "$AGSB_DIR/xrk/short_id")
    fi

    if [ -f "$AGSB_DIR/port_xh" ]; then
        _echo "\n【 vless-xhttp-reality 】"
        port_xh=$(cat "$AGSB_DIR/port_xh")
        vl_xh_link="vless://$uuid@$server_ip:$port_xh?encryption=none&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=xhttp&path=/${uuid}-xh#vless-xhttp-reality-csb-$hostname"
        _echo "$vl_xh_link"
        echo "$vl_xh_link" >> "$AGSB_DIR/jh.txt"
    fi

    if [ -f "$AGSB_DIR/port_vl_re" ]; then
        _echo "\n【 vless-reality-vision 】"
        port_vl_re=$(cat "$AGSB_DIR/port_vl_re")
        vl_link="vless://$uuid@$server_ip:$port_vl_re?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=tcp#vless-reality-vision-csb-$hostname"
        _echo "$vl_link"
        echo "$vl_link" >> "$AGSB_DIR/jh.txt"
    fi

    if [ -f "$AGSB_DIR/port_vm_ws" ]; then
        _echo "\n【 vmess-ws 】"
        port_vm_ws=$(cat "$AGSB_DIR/port_vm_ws")
        vm_link="vmess://$(echo "{\"v\":\"2\",\"ps\":\"vm-ws-csb-$hostname\",\"add\":\"$server_ip\",\"port\":\"$port_vm_ws\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/${uuid}-vm\"}" | base64 -w0)"
        _echo "$vm_link"
        echo "$vm_link" >> "$AGSB_DIR/jh.txt"
    fi

    if [ -f "$AGSB_DIR/port_an" ]; then
        _echo "\n【 anytls 】"
        port_an=$(cat "$AGSB_DIR/port_an")
        an_link="anytls://$uuid@$server_ip:$port_an?insecure=1#anytls-csb-$hostname"
        _echo "$an_link"
        echo "$an_link" >> "$AGSB_DIR/jh.txt"
    fi

    if [ -f "$AGSB_DIR/port_hy2" ]; then
        _echo "\n【 hysteria2 】"
        port_hy2=$(cat "$AGSB_DIR/port_hy2")
        hy2_link="hysteria2://$uuid@$server_ip:$port_hy2?insecure=1&sni=www.bing.com#hy2-csb-$hostname"
        _echo "$hy2_link"
        echo "$hy2_link" >> "$AGSB_DIR/jh.txt"
    fi

    if [ -f "$AGSB_DIR/port_tu" ]; then
        _echo "\n【 tuic 】"
        port_tu=$(cat "$AGSB_DIR/port_tu")
        tuic5_link="tuic://$uuid:$uuid@$server_ip:$port_tu?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=www.bing.com&allow_insecure=1#tuic-csb-$hostname"
        _echo "$tuic5_link"
        echo "$tuic5_link" >> "$AGSB_DIR/jh.txt"
    fi
}

# --- 生成 CDN 优选节点 ---
generate_cdn_nodes() {
    if [ -z "$cdn" ]; then
        return
    fi

    _echo "\n--- 正在根据 cdn 变量生成优选域名节点 (端口: 443) ---"

    uuid=$(cat "$AGSB_DIR/uuid" 2>/dev/null)
    argodomain=$(head -n 1 "$AGSB_DIR/argo.log" 2>/dev/null)

    if [ -z "$uuid" ] || [ -z "$argodomain" ]; then
        _error "未能获取到 UUID 或 Argo 域名。"
        return
    fi

    cdn_hosts=$(echo "$cdn" | tr ',' ' ')

    for host in $cdn_hosts; do
        host=$(echo "$host" | xargs)
        _echo "为域名 $host 生成节点..."
        ps_name="vmess-ws-tls-cdn-$host"
        vmess_json=$(printf '{ "v": "2", "ps": "%s", "add": "%s", "port": "443", "id": "%s", "aid": "0", "scy": "auto", "net": "ws", "type": "none", "host": "%s", "path": "/%s-vm?ed=2048", "tls": "tls", "sni": "%s" }' "$ps_name" "$host" "$uuid" "$argodomain" "${uuid}" "$argodomain")
        vmess_link="vmess://$(echo "$vmess_json" | base64 -w0)"
        _echo "$vmess_link"
        echo "$vmess_link" >> "$AGSB_DIR/jh.txt"
    done

    _echo "\n优选域名节点已添加至聚合文件: $AGSB_DIR/jh.txt"
}

# --- 卸载 CSB ---
uninstall_agsb() {
    if [ ! -d "$AGSB_DIR" ]; then
        _error "CSB 尚未安装。"
        return
    fi

    clear
    _echo "--- 卸载 CSB ---"
    printf "您确定要完全卸载 CSB 吗？[y/N]: "
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        stop_and_disable_services
        rm -f "$SERVICE_DIR"/csb-*.service
        systemctl daemon-reload
        rm -rf "$AGSB_DIR" "$BIN_DIR/$COMMAND_NAME"
        sed -i "/export PATH=\"\$HOME\/bin:\$PATH\"/d" "$HOME/.bashrc"
        _echo "\n--- 卸载完成 ---"
    else
        _echo "操作已取消。"
    fi
}

# --- 菜单显示 ---
show_menu() {
    clear
    _echo "============================================="
    _echo "          CSB 交互式管理面板 (v8.0)"
    _echo "============================================="
    _echo " 1. 安装 / 更新 CSB"
    _echo " 2. 查看节点信息"
    _echo " 3. 卸载 CSB"
    _echo "---------------------------------------------"
    _echo " 0. 退出脚本"
    _echo "============================================="
    printf "请输入选项 [0-3]: "
    read choice
}

# --- 主程序入口 ---
main() {
    check_root

    case "$1" in
        list)
            export ipsw=${ip:-''}
            display_node_info
            exit 0
            ;;
        del)
            uninstall_agsb
            exit 0
            ;;
    esac

    while true; do
        show_menu
        case $choice in
            1)
                run_installation
                _pause
                ;;
            2)
                export ipsw=${ip:-''}
                display_node_info
                _pause
                ;;
            3)
                uninstall_agsb
                _pause
                ;;
            0)
                exit 0
                ;;
            *)
                _echo "无效输入。"
                sleep 1
                ;;
        esac
    done
}

# --- 脚本执行入口 ---
main "$@"
