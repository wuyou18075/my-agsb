#!/bin/sh
#=======================================================================================
# ArgoSB 一键脚本 (优化版)
#
# · 项目地址: github.com/yonggekkk/argosb
# · 原作者: 甬哥
# · 本次重构优化: Gemini
#
# 主要优化点:
# 1. 全面采用 systemd 进行服务管理，替代 nohup 和 crontab。
# 2. 修复 ip=4/6 参数无法过滤 Argo 节点的问题。
# 3. 增加下载验证，增强脚本稳定性。
# 4. 简化进程管理逻辑。
# 5. 提供更清晰的用户操作指引。
#=======================================================================================

export LANG=en_US.UTF-8

# --- 全局变量和预设 ---
# 服务文件路径
SERVICE_DIR="/etc/systemd/system"
# 工作目录
AGSB_DIR="$HOME/agsb"
# Bin 目录
BIN_DIR="$HOME/bin"
# 脚本快捷命令
COMMAND_NAME="agsb"

# --- 核心函数 ---

# 打印信息
_echo() {
    printf "%s\n" "$@"
}

# 打印错误信息并退出
_error() {
    printf "错误: %s\n" "$@" >&2
    exit 1
}

# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        _error "此脚本需要以 root 权限运行。请使用 'sudo bash $0' 或切换到 root 用户后执行。"
    fi
}

# 停止并禁用所有相关服务
stop_and_disable_services() {
    _echo "正在停止并禁用 systemd 服务..."
    systemctl stop agsb-xray.service agsb-singbox.service agsb-cloudflared.service >/dev/null 2>&1
    systemctl disable agsb-xray.service agsb-singbox.service agsb-cloudflared.service >/dev/null 2>&1
    # 作为后备，清理任何可能残留的旧进程
    pkill -f "agsb/(s|x|c)" >/dev/null 2>&1
    _echo "服务已停止。"
}

# 创建并启用 systemd 服务
create_systemd_service() {
    local service_name="$1"
    local description="$2"
    local exec_command="$3"
    local service_file_path="$SERVICE_DIR/$service_name.service"

    _echo "正在创建 systemd 服务: $service_name"
    cat > "$service_file_path" <<EOF
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
    fi
}

# 检查并下载文件
download_file() {
    local url="$1"
    local dest="$2"
    
    _echo "正在从 $url 下载文件..."
    curl -Lo "$dest" -# --retry 2 "$url"
    if [ $? -ne 0 ]; then
        _error "下载文件失败: $url。请检查网络连接。"
    fi
    _echo "下载成功: $dest"
}

# 脚本主逻辑函数
main() {
    if ! find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'agsb/(s|x)' && ! pgrep -f 'agsb/(s|x)' >/dev/null 2>&1; then
    [ -z "${vlpt+x}" ] || vlp=yes
    [ -z "${vmpt+x}" ] || { vmp=yes; vmag=yes; }
    [ -z "${hypt+x}" ] || hyp=yes
    [ -z "${tupt+x}" ] || tup=yes
    [ -z "${xhpt+x}" ] || xhp=yes
    [ -z "${anpt+x}" ] || anp=yes
    [ "$vlp" = yes ] || [ "$vmp" = yes ] || [ "$hyp" = yes ] || [ "$tup" = yes ] || [ "$xhp" = yes ] || [ "$anp" = yes ] || { echo "提示：使用此脚本时，请在脚本前至少设置一个协议变量哦，再见！"; exit; }
    fi
    export uuid=${uuid:-''}
    export port_vl_re=${vlpt:-''}
    export port_vm_ws=${vmpt:-''}
    export port_hy2=${hypt:-''}
    export port_tu=${tupt:-''}
    export port_xh=${xhpt:-''}
    export port_an=${anpt:-''}
    export ym_vl_re=${reym:-''}
    export argo=${argo:-''}
    export ARGO_DOMAIN=${agn:-''}
    export ARGO_AUTH=${agk:-''}
    export ipsw=${ip:-''}
    showmode(){
    echo "显示节点信息：agsb 或者 $BIN_DIR/$COMMAND_NAME list"
    echo "双栈VPS显示IPv4节点配置：ip=4 agsb 或者 ip=4 $BIN_DIR/$COMMAND_NAME list"
    echo "双栈VPS显示IPv6节点配置：ip=6 agsb 或者 ip=6 $BIN_DIR/$COMMAND_NAME list"
    echo "卸载脚本：agsb del 或者 $BIN_DIR/$COMMAND_NAME del"
    }
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "甬哥Github项目 ：github.com/yonggekkk"
    echo "甬哥Blogger博客 ：ygkkk.blogspot.com"
    echo "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
    echo "ArgoSB一键无交互极简脚本【Sing-box + Xray + Argo三内核合一】(Gemini 优化版)"
    echo "当前版本：V25.7.4-Optimized"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    hostname=$(uname -a | awk '{print $2}')
    op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
    [ -z "$(systemd-detect-virt 2>/dev/null)" ] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
    case $(uname -m) in
    aarch64) cpu=arm64;;
    x86_64) cpu=amd64;;
    *) echo "目前脚本不支持$(uname -m)架构" && exit
    esac
    mkdir -p "$AGSB_DIR"
    warpcheck(){
    wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    }
    insuuid(){
    if [ -z "$uuid" ]; then
    if [ -e "$AGSB_DIR/sing-box" ]; then
    uuid=$("$AGSB_DIR/sing-box" generate uuid)
    else
    uuid=$("$AGSB_DIR/xray" uuid)
    fi
    fi
    echo "$uuid" > "$AGSB_DIR/uuid"
    echo "UUID密码：$uuid"
    }
    installxray(){
    echo
    echo "=========启用xray内核========="
    if [ ! -e "$AGSB_DIR/xray" ]; then
    download_file "https://github.com/yonggekkk/ArgoSB/releases/download/argosbx/xray-$cpu" "$AGSB_DIR/xray"
    chmod +x "$AGSB_DIR/xray"
    sbcore=$("$AGSB_DIR/xray" version 2>/dev/null | awk '/^Xray/{print $2}')
    echo "已安装Xray正式版内核：$sbcore"
    fi
    cat > "$AGSB_DIR/xr.json" <<EOF
{
  "log": {
    "access": "/dev/null",
    "error": "/dev/null",
    "loglevel": "none"
  },
  "inbounds": [
EOF
    insuuid
    if [ -n "$xhp" ] || [ -n "$vlp" ]; then
    if [ -z "$ym_vl_re" ]; then
    ym_vl_re=www.yahoo.com
    fi
    echo "$ym_vl_re" > "$AGSB_DIR/ym_vl_re"
    echo "Reality域名：$ym_vl_re"
    mkdir -p "$AGSB_DIR/xrk"
    if [ ! -e "$AGSB_DIR/xrk/private_key" ]; then
    key_pair=$("$AGSB_DIR/xray" x25519)
    private_key=$(echo "$key_pair" | head -1 | awk '{print $3}')
    public_key=$(echo "$key_pair" | tail -n 1 | awk '{print $3}')
    short_id=$(date +%s%N | sha256sum | cut -c 1-8)
    echo "$private_key" > "$AGSB_DIR/xrk/private_key"
    echo "$public_key" > "$AGSB_DIR/xrk/public_key"
    echo "$short_id" > "$AGSB_DIR/xrk/short_id"
    fi
    private_key_x=$(cat "$AGSB_DIR/xrk/private_key")
    public_key_x=$(cat "$AGSB_DIR/xrk/public_key")
    short_id_x=$(cat "$AGSB_DIR/xrk/short_id")
    fi
    if [ -n "$xhp" ]; then
    xhp=xhpt
    if [ -z "$port_xh" ]; then
    port_xh=$(shuf -i 10000-65535 -n 1)
    fi
    echo "$port_xh" > "$AGSB_DIR/port_xh"
    echo "Vless-xhttp-reality端口：$port_xh"
    cat >> "$AGSB_DIR/xr.json" <<EOF
    {
      "tag":"xhttp-reality",
      "listen": "::",
      "port": ${port_xh},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "reality",
        "realitySettings": {
          "fingerprint": "chrome",
          "target": "${ym_vl_re}:443",
          "serverNames": [
            "${ym_vl_re}"
          ],
          "privateKey": "$private_key_x",
          "shortIds": ["$short_id_x"]
        },
        "xhttpSettings": {
          "host": "",
          "path": "${uuid}-xh",
          "mode": "auto"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
    else
    xhp=xhptargo
    fi
    if [ -n "$vlp" ]; then
    vlp=vlpt
    if [ -z "$port_vl_re" ]; then
    port_vl_re=$(shuf -i 10000-65535 -n 1)
    fi
    echo "$port_vl_re" > "$AGSB_DIR/port_vl_re"
    echo "Vless-reality-vision端口：$port_vl_re"
    cat >> "$AGSB_DIR/xr.json" <<EOF
        {
            "tag":"reality-vision",
            "listen": "::",
            "port": $port_vl_re,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "fingerprint": "chrome",
                    "dest": "${ym_vl_re}:443",
                    "serverNames": [
                        "${ym_vl_re}"
                    ],
                    "privateKey": "$private_key_x",
                    "shortIds": ["$short_id_x"]
                }
            },
          "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls", "quic"],
            "metadataOnly": false
          }
    },
EOF
    else
    vlp=vlptargo
    fi
    }

    installsb(){
    echo
    echo "=========启用Sing-box内核========="
    if [ ! -e "$AGSB_DIR/sing-box" ]; then
    download_file "https://github.com/yonggekkk/ArgoSB/releases/download/argosbx/sing-box-$cpu" "$AGSB_DIR/sing-box"
    chmod +x "$AGSB_DIR/sing-box"
    sbcore=$("$AGSB_DIR/sing-box" version 2>/dev/null | awk '/version/{print $NF}')
    echo "已安装Sing-box正式版内核：$sbcore"
    fi
    cat > "$AGSB_DIR/sb.json" <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
EOF
    insuuid
    command -v openssl >/dev/null 2>&1 && openssl ecparam -genkey -name prime256v1 -out "$AGSB_DIR/private.key" >/dev/null 2>&1
    command -v openssl >/dev/null 2>&1 && openssl req -new -x509 -days 36500 -key "$AGSB_DIR/private.key" -out "$AGSB_DIR/cert.pem" -subj "/CN=www.bing.com" >/dev/null 2>&1
    if [ ! -f "$AGSB_DIR/private.key" ]; then
    download_file "https://github.com/yonggekkk/ArgoSB/releases/download/argosbx/private.key" "$AGSB_DIR/private.key"
    download_file "https://github.com/yonggekkk/ArgoSB/releases/download/argosbx/cert.pem" "$AGSB_DIR/cert.pem"
    fi
    if [ -n "$hyp" ]; then
    hyp=hypt
    if [ -z "$port_hy2" ]; then
    port_hy2=$(shuf -i 10000-65535 -n 1)
    fi
    echo "$port_hy2" > "$AGSB_DIR/port_hy2"
    echo "Hysteria-2端口：$port_hy2"
    cat >> "$AGSB_DIR/sb.json" <<EOF
    {
        "type": "hysteria2",
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$AGSB_DIR/cert.pem",
            "key_path": "$AGSB_DIR/private.key"
        }
    },
EOF
    else
    hyp=hyptargo
    fi
    if [ -n "$tup" ]; then
    tup=tupt
    if [ -z "$port_tu" ]; then
    port_tu=$(shuf -i 10000-65535 -n 1)
    fi
    echo "$port_tu" > "$AGSB_DIR/port_tu"
    echo "Tuic端口：$port_tu"
    cat >> "$AGSB_DIR/sb.json" <<EOF
        {
            "type":"tuic",
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$AGSB_DIR/cert.pem",
                "key_path": "$AGSB_DIR/private.key"
            }
        },
EOF
    else
    tup=tuptargo
    fi
    if [ -n "$anp" ]; then
    anp=anpt
    if [ -z "$port_an" ]; then
    port_an=$(shuf -i 10000-65535 -n 1)
    fi
    echo "$port_an" > "$AGSB_DIR/port_an"
    echo "Anytls端口：$port_an"
    cat >> "$AGSB_DIR/sb.json" <<EOF
        {
            "type":"anytls",
            "tag":"anytls-sb",
            "listen":"::",
            "listen_port":${port_an},
            "users":[
                {
                    "password":"${uuid}"
                }
            ],
            "padding_scheme":[],
            "tls":{
                "enabled": true,
                "certificate_path": "$AGSB_DIR/cert.pem",
                "key_path": "$AGSB_DIR/private.key"
            }
        },
EOF
    else
    anp=anptargo
    fi
    }

    xrsbvm(){
    if [ -n "$vmp" ]; then
    vmp=vmpt
    if [ -z "$port_vm_ws" ]; then
    port_vm_ws=$(shuf -i 10000-65535 -n 1)
    fi
    echo "$port_vm_ws" > "$AGSB_DIR/port_vm_ws"
    echo "Vmess-ws端口：$port_vm_ws"
    if [ -e "$AGSB_DIR/xray" ]; then
    cat >> "$AGSB_DIR/xr.json" <<EOF
        {
            "tag": "vmess-xr",
            "listen": "::",
            "port": ${port_vm_ws},
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}"
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "/${uuid}-vm"
                }
            },
            "sniffing": {
              "enabled": true,
              "destOverride": ["http", "tls", "quic"],
              "metadataOnly": false
            }
        },
EOF
    else
    cat >> "$AGSB_DIR/sb.json" <<EOF
{
        "type": "vmess",
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "/${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
        }
    },
EOF
    fi
    else
    vmp=vmptargo
    fi
    }

    finalize_and_start_services() {
    local xray_installed=0
    local singbox_installed=0
    local argo_installed=0

    if [ -e "$AGSB_DIR/xray" ]; then
    sed -i '${s/,\s*$//}' "$AGSB_DIR/xr.json"
    cat >> "$AGSB_DIR/xr.json" <<EOF
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
    create_systemd_service "agsb-xray" "ArgoSB Xray Service" "$AGSB_DIR/xray run -c $AGSB_DIR/xr.json"
    xray_installed=1
    fi

    if [ -e "$AGSB_DIR/sing-box" ]; then
    sed -i '${s/,\s*$//}' "$AGSB_DIR/sb.json"
    cat >> "$AGSB_DIR/sb.json" <<EOF
],
"outbounds": [
{
"type":"direct",
"tag":"direct"
}
]
}
EOF
    create_systemd_service "agsb-singbox" "ArgoSB Sing-box Service" "$AGSB_DIR/sing-box run -c $AGSB_DIR/sb.json"
    singbox_installed=1
    fi

    if [ -n "$argo" ] && [ -n "$vmag" ]; then
        echo
        echo "=========启用Cloudflared-argo内核========="
        if [ ! -e "$AGSB_DIR/cloudflared" ]; then
        argocore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/cloudflare/cloudflared | grep -Eo '"[0-9.]+"' | sed -n 1p | tr -d '",')
        echo "下载Cloudflared-argo最新正式版内核：$argocore"
        download_file "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu" "$AGSB_DIR/cloudflared"
        chmod +x "$AGSB_DIR/cloudflared"
        fi
        local argo_exec_cmd=""
        if [ -n "${ARGO_DOMAIN}" ] && [ -n "${ARGO_AUTH}" ]; then
            name='固定'
            argo_exec_cmd="$AGSB_DIR/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token ${ARGO_AUTH}"
            echo "${ARGO_DOMAIN}" > "$AGSB_DIR/sbargoym.log"
            echo "${ARGO_AUTH}" > "$AGSB_DIR/sbargotoken.log"
        else
            name='临时'
            argo_exec_cmd="$AGSB_DIR/cloudflared tunnel --url http://localhost:${port_vm_ws} --edge-ip-version auto --no-autoupdate --protocol http2"
        fi
        
        create_systemd_service "agsb-cloudflared" "ArgoSB Cloudflared Service" "$argo_exec_cmd"
        argo_installed=1
    fi

    _echo "正在重载 systemd 并启动服务..."
    systemctl daemon-reload
    
    if [ "$xray_installed" -eq 1 ]; then systemctl enable --now agsb-xray.service; fi
    if [ "$singbox_installed" -eq 1 ]; then systemctl enable --now agsb-singbox.service; fi
    if [ "$argo_installed" -eq 1 ]; then
        systemctl enable --now agsb-cloudflared.service
        echo "正在等待 Argo 隧道建立... (约8秒)"
        sleep 8
        if [ -z "${ARGO_DOMAIN}" ]; then
            # 临时隧道需要从日志获取域名
            journalctl -u agsb-cloudflared.service --no-pager -n 10 | grep -a 'trycloudflare.com' | awk 'NR==1{print $NF}' | sed 's|https://||' > "$AGSB_DIR/argo.log"
        fi
    fi
    }
    
    ins(){
    if [ "$hyp" != yes ] && [ "$tup" != yes ] && [ "$anp" != yes ]; then
    installxray
    xrsbvm
    hyp="hyptargo"; tup="tuptargo"; anp="anptargo"
    elif [ "$xhp" != yes ] && [ "$vlp" != yes ]; then
    installsb
    xrsbvm
    xhp="xhptargo"; vlp="vlptargo"
    else
    installsb
    installxray
    xrsbvm
    fi
    
    finalize_and_start_services

    echo
    if pgrep -f "agsb/(s|x|c)" >/dev/null 2>&1 ; then
    [ -f ~/.bashrc ] || touch ~/.bashrc
    sed -i '/yonggekkk/d' ~/.bashrc
    echo "if ! find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'agsb/(s|x)' && ! pgrep -f 'agsb/(s|x)' >/dev/null 2>&1; then export ip=\"${ipsw}\" argo=\"${argo}\" uuid=\"${uuid}\" $xhp=\"${port_xh}\" $anp=\"${port_an}\" $vlp=\"${port_vl_re}\" $vmp=\"${port_vm_ws}\" $hyp=\"${port_hy2}\" $tup=\"${port_tu}\" reym=\"${ym_vl_re}\" agn=\"${ARGO_DOMAIN}\" agk=\"${ARGO_AUTH}\"; bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh); fi" >> ~/.bashrc
    
    mkdir -p "$BIN_DIR"
    download_file "https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh" "$BIN_DIR/$COMMAND_NAME"
    chmod +x "$BIN_DIR/$COMMAND_NAME"

    # Add bin to PATH if it's not already there
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    
    grep -qxF 'source ~/.bashrc' ~/.bash_profile 2>/dev/null || echo 'source ~/.bashrc' >> ~/.bash_profile
    
    echo "ArgoSB脚本安装成功，服务已启动" && sleep 2
    else
    echo "ArgoSB脚本进程未启动，安装失败" && exit
    fi
    }
    cip(){
    ipbest(){
    serip=$(curl -s4m5 icanhazip.com -k || curl -s6m5 icanhazip.com -k)
    if echo "$serip" | grep -q ':'; then
    server_ip="[$serip]"
    echo "$server_ip" > "$AGSB_DIR/server_ip.log"
    else
    server_ip="$serip"
    echo "$server_ip" > "$AGSB_DIR/server_ip.log"
    fi
    }
    ipchange(){
    v4=$(curl -s4m5 icanhazip.com -k)
    v6=$(curl -s6m5 icanhazip.com -k)
    if [ -z "$v4" ]; then
    vps_ipv4='无IPV4'
    vps_ipv6="$v6"
    elif [ -n "$v4" ] && [ -n "$v6" ]; then
    vps_ipv4="$v4"
    vps_ipv6="$v6"
    else
    vps_ipv4="$v4"
    vps_ipv6='无IPV6'
    fi
    echo
    echo "=========当前服务器本地IP情况========="
    echo "本地IPV4地址：$vps_ipv4"
    echo "本地IPV6地址：$vps_ipv6"
    echo
    if [ "$ipsw" = "4" ]; then
    if [ -z "$v4" ]; then
    ipbest
    else
    server_ip="$v4"
    echo "$server_ip" > "$AGSB_DIR/server_ip.log"
    fi
    elif [ "$ipsw" = "6" ]; then
    if [ -z "$v6" ]; then
    ipbest
    else
    server_ip="[$v6]"
    echo "$server_ip" > "$AGSB_DIR/server_ip.log"
    fi
    else
    ipbest
    fi
    }
    warpcheck
    if ! echo "$wgcfv4" | grep -qE 'on|plus' && ! echo "$wgcfv6" | grep -qE 'on|plus'; then
    ipchange
    else
    systemctl stop wg-quick@wgcf >/dev/null 2>&1
    kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
    ipchange
    systemctl start wg-quick@wgcf >/dev/null 2>&1
    systemctl restart warp-go >/dev/null 2>&1
    systemctl enable warp-go >/dev/null 2>&1
    systemctl start warp-go >/dev/null 2>&1
    fi
    rm -rf "$AGSB_DIR/jh.txt"
    uuid=$(cat "$AGSB_DIR/uuid")
    server_ip=$(cat "$AGSB_DIR/server_ip.log")
    echo "*********************************************************"
    echo "*********************************************************"
    echo "ArgoSB脚本输出节点配置如下："
    echo
    if [ -f "$AGSB_DIR/port_xh" ] || [ -f "$AGSB_DIR/port_vl_re" ]; then
    ym_vl_re=$(cat "$AGSB_DIR/ym_vl_re")
    private_key_x=$(cat "$AGSB_DIR/xrk/private_key")
    public_key_x=$(cat "$AGSB_DIR/xrk/public_key")
    short_id_x=$(cat "$AGSB_DIR/xrk/short_id")
    fi
    if [ -f "$AGSB_DIR/port_xh" ]; then
    echo "【 vless-xhttp-reality 】节点信息如下："
    port_xh=$(cat "$AGSB_DIR/port_xh")
    vl_xh_link="vless://$uuid@$server_ip:$port_xh?encryption=none&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=xhttp&path=/${uuid}-xh&mode=auto#vl-xhttp-reality-$hostname"
    echo "$vl_xh_link" >> "$AGSB_DIR/jh.txt"
    echo "$vl_xh_link"
    echo
    fi
    if [ -f "$AGSB_DIR/port_vl_re" ]; then
    echo "【 vless-reality-vision 】节点信息如下："
    port_vl_re=$(cat "$AGSB_DIR/port_vl_re")
    vl_link="vless://$uuid@$server_ip:$port_vl_re?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=tcp&headerType=none#vl-reality-vision-$hostname"
    echo "$vl_link" >> "$AGSB_DIR/jh.txt"
    echo "$vl_link"
    echo
    fi
    if [ -f "$AGSB_DIR/port_vm_ws" ]; then
    echo "【 vmess-ws 】节点信息如下："
    port_vm_ws=$(cat "$AGSB_DIR/port_vm_ws")
    vm_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"vm-ws-$hostname\", \"add\": \"$server_ip\", \"port\": \"$port_vm_ws\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"www.bing.com\", \"path\": \"/${uuid}-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
    echo "$vm_link" >> "$AGSB_DIR/jh.txt"
    echo "$vm_link"
    echo
    fi
    if [ -f "$AGSB_DIR/port_an" ]; then
    echo "【 AnyTLS 】节点信息如下："
    port_an=$(cat "$AGSB_DIR/port_an")
    an_link="anytls://$uuid@$server_ip:$port_an?insecure=1#anytls-$hostname"
    echo "$an_link" >> "$AGSB_DIR/jh.txt"
    echo "$an_link"
    echo
    fi
    if [ -f "$AGSB_DIR/port_hy2" ]; then
    echo "【 Hysteria2 】节点信息如下："
    port_hy2=$(cat "$AGSB_DIR/port_hy2")
    hy2_link="hysteria2://$uuid@$server_ip:$port_hy2?security=tls&alpn=h3&insecure=1&sni=www.bing.com#hy2-$hostname"
    echo "$hy2_link" >> "$AGSB_DIR/jh.txt"
    echo "$hy2_link"
    echo
    fi
    if [ -f "$AGSB_DIR/port_tu" ]; then
    echo "【 Tuic 】节点信息如下："
    port_tu=$(cat "$AGSB_DIR/port_tu")
    tuic5_link="tuic://$uuid:$uuid@$server_ip:$port_tu?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=www.bing.com&allow_insecure=1#tu5-$hostname"
    echo "$tuic5_link" >> "$AGSB_DIR/jh.txt"
    echo "$tuic5_link"
    echo
    fi
    
    argodomain=$(cat "$AGSB_DIR/sbargoym.log" 2>/dev/null)
    [ -z "$argodomain" ] && argodomain=$(cat "$AGSB_DIR/argo.log" 2>/dev/null)
    
    if [ -n "$argodomain" ]; then
        echo "------------------- Argo 隧道节点 -------------------"
        local argoshow=""
        # 如果用户没有强制指定只用IPv6 (ipsw != 6)，则输出IPv4的Argo节点
        if [ "$ipsw" != "6" ]; then
            vmatls_link1="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"vmess-ws-tls-argo-$hostname-443\", \"add\": \"104.16.0.0\", \"port\": \"443\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/${uuid}-vm?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\"}" | base64 -w0)"
            vma_link7="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"vmess-ws-argo-$hostname-80\", \"add\": \"104.21.0.0\", \"port\": \"80\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/${uuid}-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
            # ... 此处可以添加更多IPv4的Argo优选IP节点
            echo "$vmatls_link1" >> "$AGSB_DIR/jh.txt"
            echo "$vma_link7" >> "$AGSB_DIR/jh.txt"
            argoshow="${argoshow}1、(TLS) 443端口的vmess-ws-tls-argo节点\n$vmatls_link1\n\n2、(非TLS) 80端口的vmess-ws-argo节点\n$vma_link7\n"
        fi

        # 如果用户没有强制指定只用IPv4 (ipsw != 4)，则输出IPv6的Argo节点
        if [ "$ipsw" != "4" ]; then
            vmatls_link6="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"vmess-ws-tls-argo-$hostname-2096\", \"add\": \"[2606:4700::0]\", \"port\": \"2096\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/${uuid}-vm?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\"}" | base64 -w0)"
            vma_link13="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"vmess-ws-argo-$hostname-2095\", \"add\": \"[2400:cb00:2049::0]\", \"port\": \"2095\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/${uuid}-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
            echo "$vmatls_link6" >> "$AGSB_DIR/jh.txt"
            echo "$vma_link13" >> "$AGSB_DIR/jh.txt"
            argoshow="${argoshow}\n3、(TLS-IPv6) 2096端口的vmess-ws-tls-argo节点\n$vmatls_link6\n\n4、(非TLS-IPv6) 2095端口的vmess-ws-argo节点\n$vma_link13\n"
        fi
        
        sbtk=$(cat "$AGSB_DIR/sbargotoken.log" 2>/dev/null)
        if [ -n "$sbtk" ]; then
            nametn="当前Argo固定隧道token：$sbtk"
        fi
        port_vm_ws=$(cat "$AGSB_DIR/port_vm_ws" 2>/dev/null)
        
        _echo -e "Argo隧道域名：$argodomain"
        _echo -e "$nametn"
        _echo "Vmess主协议端口(Argo固定隧道使用此端口)：$port_vm_ws"
        _echo -e "$argoshow"
    fi

    echo "---------------------------------------------------------"
    echo "聚合节点信息，请查看$AGSB_DIR/jh.txt文件或者运行cat $AGSB_DIR/jh.txt进行复制"
    echo "---------------------------------------------------------"
    echo "相关快捷方式如下：(首次安装成功后需重连SSH，agsb快捷方式才可生效)"
    showmode
    echo "---------------------------------------------------------"
    echo -e "\n\n重要提示：快捷命令 'agsb' 安装成功！"
    echo "但它在您当前的终端窗口中可能还不能直接使用。"
    echo "请选择以下任一方式激活它："
    echo "  1. (推荐) 断开并重新连接您的 SSH 会话。"
    echo "  2. (临时) 在当前终端中执行命令: source ~/.bashrc"
    echo
    }

    # --- 脚本执行入口 ---
    check_root

    case "$1" in
        del)
            _echo "开始卸载 ArgoSB 脚本..."
            stop_and_disable_services
            rm -f $SERVICE_DIR/agsb-xray.service $SERVICE_DIR/agsb-singbox.service $SERVICE_DIR/agsb-cloudflared.service
            systemctl daemon-reload
            
            sed -i '/yonggekkk/d' ~/.bashrc
            sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc
            
            # 清理旧的 crontab (以防万一)
            crontab -l 2>/dev/null | sed '/agsb\//d' | crontab -
            
            rm -rf "$AGSB_DIR" "$BIN_DIR/$COMMAND_NAME"
            _echo "卸载完成。"
            _echo "请手动执行 'source ~/.bashrc' 或重连SSH来让环境变更生效。"
            exit 0
            ;;
        list)
            cip
            exit 0
            ;;
    esac

    if pgrep -f "agsb/(s|x|c)" >/dev/null 2>&1 || systemctl is-active --quiet agsb-xray.service || systemctl is-active --quiet agsb-singbox.service ; then
        _echo "ArgoSB 脚本已安装且服务正在运行。"
        _echo "相关快捷方式如下："
        showmode
        exit 0
    else
        _echo "正在清理旧环境..."
        stop_and_disable_services # 清理可能存在的服务但不卸载
        _echo "VPS系统：$op"
        _echo "CPU架构：$cpu"
        _echo "ArgoSB脚本未安装，开始安装…………" && sleep 2
        setenforce 0 >/dev/null 2>&1
        iptables -P INPUT ACCEPT >/dev/null 2>&1
        iptables -P FORWARD ACCEPT >/dev/null 2>&1
        iptables -P OUTPUT ACCEPT >/dev/null 2>&1
        iptables -F >/dev/null 2>&1
        netfilter-persistent save >/dev/null 2>&1
        ins
        cip
    fi
}

# --- 执行主函数 ---
# 将原始命令行参数传递给 main 函数，例如 'del', 'list'
main "$@"
