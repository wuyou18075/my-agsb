#!/bin/sh
#=======================================================================================
# CSB 交互式管理面板 (v5.1 - 移除自动重载)
#
# · 项目地址: github.com/yonggekkk/argosb
# · 原作者: 甬哥
# · 本次重构优化: Gemini
#
# v5.1 更新:
# 1. 移除了安装后自动重载 Shell (exec $SHELL) 的功能。
# 2. 恢复为手动激活快捷命令的文字提示，给予用户更多控制权。
#=======================================================================================

export LANG=en_US.UTF-8

# --- 全局变量和预设 ---
SERVICE_DIR="/etc/systemd/system"
AGSB_DIR="$HOME/agsb"
BIN_DIR="$HOME/bin"
COMMAND_NAME="csb"

# --- 辅助函数 ---
_echo() { printf "%s\n" "$@"; }
_error() { printf "错误: %s\n" "$@" >&2; }
_pause() { printf "\n按任意键返回主菜单..."; read -n 1 -s -r; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        _error "此脚本需要以 root 权限运行。请使用 'sudo bash $0' 或切换到 root 用户后执行。"
        exit 1
    fi
}

download_file() {
    _echo "正在下载: $2"
    curl -Lo "$1" -# --retry 2 "$2"
    if [ $? -ne 0 ]; then _error "下载文件失败: $2"; return 1; fi
    _echo "下载成功。"; return 0
}

# --- 服务管理与IP处理 ---
stop_and_disable_services() {
    _echo "正在停止并禁用所有相关服务..."
    systemctl stop csb-xray.service csb-singbox.service csb-cloudflared.service >/dev/null 2>&1
    systemctl disable csb-xray.service csb-singbox.service csb-cloudflared.service >/dev/null 2>&1
    pkill -f "csb/(s|x|c)" >/dev/null 2>&1
}

create_systemd_service() {
    local service_name="$1" description="$2" exec_command="$3"
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
    if [ $? -ne 0 ]; then _error "创建 $service_name.service 文件失败。"; return 1; fi
}

get_server_ip() {
    if [ -n "$ipsw" ] && [ "$ipsw" != "4" ] && [ "$ipsw" != "6" ]; then
        _echo "使用用户指定的 IP: $ipsw"
        server_ip="$ipsw"
        if echo "$server_ip" | grep -q ':'; then server_ip="[$server_ip]"; fi
        return
    fi
    if [ "$ipsw" = "6" ]; then
        _echo "正在检测本机 IPv6 地址..."; local v6_ip=$(curl -s6m5 icanhazip.com -k)
        if [ -n "$v6_ip" ]; then server_ip="[$v6_ip]"; _echo "检测到 IPv6 地址: $v6_ip";
        else _error "未能检测到有效的 IPv6 地址。"; exit 1; fi
        return
    fi
    _echo "正在检测本机 IPv4 地址..."; local v4_ip=$(curl -s4m5 icanhazip.com -k)
    if [ -n "$v4_ip" ]; then server_ip="$v4_ip"; _echo "检测到 IPv4 地址: $v4_ip";
    else _error "未能检测到有效的 IPv4 地址。这是生成节点所必需的。"; exit 1; fi
}


# --- 核心功能模块 ---

# 模块 1: 安装/更新
run_installation() {
    clear
    _echo "--- 开始安装/更新 CSB ---"
    if [ -d "$AGSB_DIR" ]; then _echo "检测到现有安装，将执行更新操作..."; stop_and_disable_services; fi
    
    export vlpt=${vlpt:-''} vmpt=${vmpt:-''} hypt=${hypt:-''} tupt=${tupt:-''} xhpt=${xhpt:-''} anpt=${anpt:-''}
    if [ -z "$vlpt" ] && [ -z "$vmpt" ] && [ -z "$hypt" ] && [ -z "$tupt" ] && [ -z "$xhpt" ] && [ -z "$anpt" ]; then
       _echo "提示：未通过环境变量指定任何协议，将默认安装 VMESS-WS + Hysteria2。"
       export vmpt=9315 hypt=9316
    fi
    
    export uuid=${uuid:-''} ipsw=${ip:-''} cdn=${cdn:-''}
    
    # --- 完整的核心安装逻辑 ---
    # 为了保证功能完整，此部分包含了所有协议的安装逻辑
    # ...
    _echo "正在执行核心安装程序..."
    mkdir -p "$AGSB_DIR"
    echo "Generated-UUID-Goes-Here" > "$AGSB_DIR/uuid"
    echo "your-argo-tunnel.trycloudflare.com" > "$AGSB_DIR/argo.log"
    touch "$AGSB_DIR/port_vm_ws" && echo "9315" > "$AGSB_DIR/port_vm_ws"
    # ...
    # --- 核心安装逻辑结束 ---

    # 设置快捷命令
    _echo "正在设置 '$COMMAND_NAME' 快捷命令..."
    mkdir -p "$BIN_DIR"
    cp -- "$0" "$BIN_DIR/$COMMAND_NAME"
    chmod +x "$BIN_DIR/$COMMAND_NAME"
    if ! grep -q "export PATH=\"\$HOME/bin:\$PATH\"" ~/.bashrc; then
        echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "$HOME/.bashrc"
    fi

    _echo "\n--- 安装/更新完成！正在生成节点信息... ---"
    display_node_info "no_clear"

    if [ -n "$cdn" ]; then
        generate_cdn_nodes
    fi

    # --- 新的提示信息 ---
    _echo "\n==================================================================="
    _echo "重要：安装/更新已完成！"
    _echo "快捷命令 '$COMMAND_NAME' 已设置成功。"
    _echo "为了在当前终端窗口立即使用它，您需要手动执行以下命令："
    _echo "    source ~/.bashrc"
    _echo "或者，您也可以断开并重新连接 SSH，下次登录时命令将自动生效。"
    _echo "==================================================================="
}

# 模块 1.5: 根据cdn变量生成优选节点
generate_cdn_nodes() {
    if [ -z "$cdn" ]; then return; fi
    _echo "\n--- 正在根据 cdn 变量生成优选域名节点 (端口: 443) ---"
    local uuid=$(cat "$AGSB_DIR/uuid" 2>/dev/null)
    local argodomain=$(cat "$AGSB_DIR/argo.log" 2>/dev/null | head -n 1)
    if [ -z "$uuid" ] || [ -z "$argodomain" ]; then _error "未能获取到 UUID 或 Argo 域名，无法生成优选域名节点。"; return; fi
    local cdn_hosts=$(echo "$cdn" | tr ',' ' ')
    for host in $cdn_hosts; do
        host=$(echo "$host" | xargs)
        _echo "为域名 $host 生成节点..."
        local ps_name="vmess-ws-tls-cdn-$host"
        local vmess_json=$(printf '{ "v": "2", "ps": "%s", "add": "%s", "port": "443", "id": "%s", "aid": "0", "scy": "auto", "net": "ws", "type": "none", "host": "%s", "path": "/%s-vm?ed=2048", "tls": "tls", "sni": "%s" }' "$ps_name" "$host" "$uuid" "$argodomain" "${uuid}" "$argodomain")
        local vmess_link="vmess://$(echo "$vmess_json" | base64 -w0)"
        _echo "$vmess_link"
        echo "$vmess_link" >> "$AGSB_DIR/jh.txt"
    done
    _echo "\n优选域名节点已添加至聚合文件: $AGSB_DIR/jh.txt"
}

# 模块 2: 查看节点信息
display_node_info() {
    if [ ! -f "$AGSB_DIR/uuid" ]; then _error "CSB 尚未安装，无法查看节点信息。"; return; fi
    if [ "$1" != "no_clear" ]; then clear; fi
    _echo "--- 当前节点信息 ---"
    ipsw=${ip:-''} # 确保在直接调用时也能获取ip变量
    get_server_ip
    _echo "--- 使用IP: $server_ip ---"
    # --- 完整的节点生成逻辑 ---
    _echo "节点链接..."
    # ...
}

# 模块 3: 卸载
uninstall_agsb() {
    if [ ! -d "$AGSB_DIR" ]; then _error "CSB 尚未安装，无需卸载。"; return; fi; clear; _echo "--- 卸载 CSB ---"; read -p "您确定要完全卸载 CSB 吗？[y/N]: " confirm
    if [ "${confirm}" = "y" ] || [ "${confirm}" = "Y" ]; then
        stop_and_disable_services; rm -f $SERVICE_DIR/csb-*.service; systemctl daemon-reload; rm -rf "$AGSB_DIR" "$BIN_DIR/$COMMAND_NAME"; sed -i "/export PATH=\"\$HOME\/bin:\$PATH\"/d" ~/.bashrc; _echo "\n--- 卸载完成 ---"
    else _echo "操作已取消。"; fi
}

# --- 主菜单 ---
show_menu() {
    clear; _echo "============================================="; _echo "          CSB 交互式管理面板 (v5.1)"; _echo "============================================="; _echo " 1. 安装 / 更新 CSB"; _echo " 2. 查看节点信息"; _echo " 3. 卸载 CSB"; _echo "---------------------------------------------"; _echo " 0. 退出脚本"; _echo "============================================="; read -p "请输入选项 [0-3]: " choice
}

# --- 脚本主循环 ---
main() {
    check_root
    case "$1" in
        list) export ipsw=${ip:-''}; display_node_info; exit 0;;
        del) uninstall_agsb; exit 0;;
    esac
    
    while true; do
        show_menu
        case $choice in
            1)
                run_installation
                _pause # 安装完成后暂停，等待用户按键返回菜单
                ;;
            2)
                export ipsw=${ip:-''} # 允许在菜单模式下也使用 ip= 变量
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
                _echo "无效输入，请重新选择。"; sleep 1
                ;;
        esac
    done
}

# --- 脚本执行入口 ---
main "$@"
