#!/bin/bash

# ==========================================================
#  XrayR Installer & Manager - Tương thích V2board & VLESS
#  Hỗ trợ: VMess, VLESS, Trojan với Xray-core mới nhất
#  Chứng chỉ mặc định: /etc/XrayR/certvpn.crt & certvpn.key
# ==========================================================

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Kiểm tra quyền root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: Bạn phải chạy script này với quyền root!${plain}\n" && exit 1

# Kiểm tra hệ điều hành
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Không phát hiện được hệ điều hành phù hợp!${plain}\n" && exit 1
fi

# Nhận diện kiến trúc CPU
arch=$(uname -m)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${yellow}Không xác định được kiến trúc, dùng mặc định 64-bit: ${arch}${plain}"
fi

# Cài đặt các gói phụ thuộc
install_base() {
    echo -e "${green}Đang cập nhật hệ thống và cài đặt gói phụ thuộc...${plain}"
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install openssl wget curl unzip tar crontabs socat ca-certificates -y
        systemctl stop firewalld 2>/dev/null
        systemctl disable firewalld 2>/dev/null
    else
        apt update -y
        apt install openssl wget curl unzip tar cron socat ca-certificates -y
        ufw disable 2>/dev/null
    fi
}

# Tạo chứng chỉ certvpn
generate_cert() {
    mkdir -p /etc/XrayR/
    if [[ ! -f /etc/XrayR/certvpn.crt || ! -f /etc/XrayR/certvpn.key ]]; then
        echo -e "${green}Đang tạo chứng chỉ SSL tự ký certvpn...${plain}"
        openssl req -newkey rsa:2048 -x509 -sha256 -days 3650 -nodes \
            -out /etc/XrayR/certvpn.crt -keyout /etc/XrayR/certvpn.key \
            -subj "/C=VN/ST=Hanoi/L=Hanoi/O=CertVPN/CN=certvpn.com" 2>/dev/null
        chmod 644 /etc/XrayR/certvpn.crt
        chmod 600 /etc/XrayR/certvpn.key
        echo -e "${green}Đã tạo: /etc/XrayR/certvpn.crt & certvpn.key${plain}"
    fi
}

# Cài đặt XrayR binary (Hỗ trợ Báo cáo IP Online & VLESS)
install_core() {
    echo -e "${green}Đang tải nhân XrayR (Hỗ trợ giới hạn IP Online & VLESS)...${plain}"
    mkdir -p /usr/local/XrayR/
    cd /usr/local/XrayR/

    # Nguồn 1: Tải từ chính GitHub Release của bạn (tuangiangbp95) - Tự chủ 100% không sợ chết link
    url="https://github.com/tuangiangbp95/xrayr-vpn/releases/download/v1.0/XrayR-linux-${arch}.zip"
    wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}

    # Nguồn 2: Tải dự phòng từ web server gocvpn.net
    if [[ $? -ne 0 || ! -s /usr/local/XrayR/XrayR-linux.zip ]]; then
        echo -e "${yellow}Thử nguồn dự phòng từ web gocvpn.net...${plain}"
        url="https://gocvpn.net/XrayR-linux-${arch}.zip"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
    fi

    # Nguồn 3: Tải dự phòng từ qtai2901
    if [[ $? -ne 0 || ! -s /usr/local/XrayR/XrayR-linux.zip ]]; then
        echo -e "${yellow}Thử nguồn dự phòng 2...${plain}"
        url="https://github.com/qtai2901/xrayr/releases/download/0.9.0/XrayR-linux-${arch}.zip"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
    fi

    # Nguồn 4: Tải dự phòng từ XrayR-project
    if [[ $? -ne 0 || ! -s /usr/local/XrayR/XrayR-linux.zip ]]; then
        echo -e "${yellow}Thử nguồn dự phòng chính thức XrayR-project...${plain}"
        url="https://github.com/XrayR-project/XrayR/releases/download/v0.9.4/XrayR-linux-${arch}.zip"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
    fi

    if [[ ! -s /usr/local/XrayR/XrayR-linux.zip ]]; then
        echo -e "${red}Lỗi: Không tải được file XrayR-linux.zip từ tất cả các nguồn!${plain}"
        exit 1
    fi

    unzip -o XrayR-linux.zip
    rm -f XrayR-linux.zip
    chmod +x /usr/local/XrayR/XrayR

    # Copy geo và config template files
    mkdir -p /etc/XrayR/
    [[ -f geoip.dat ]] && cp -f geoip.dat /etc/XrayR/
    [[ -f geosite.dat ]] && cp -f geosite.dat /etc/XrayR/
    [[ -f custom_outbound.json ]] && cp -f custom_outbound.json /etc/XrayR/
    [[ -f route.json ]] && cp -f route.json /etc/XrayR/
    [[ -f dns.json ]] && cp -f dns.json /etc/XrayR/
    [[ -f custom_inbound.json ]] && cp -f custom_inbound.json /etc/XrayR/
    [[ -f rulelist ]] && cp -f rulelist /etc/XrayR/

    # Tạo Systemd Service
    cat > /etc/systemd/system/XrayR.service <<EOF
[Unit]
Description=XrayR Service
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
WorkingDirectory=/usr/local/XrayR/
ExecStart=/usr/local/XrayR/XrayR -config /etc/XrayR/config.yml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable XrayR

    # Tạo lệnh tắt xrayr trong terminal
    cat > /usr/bin/xrayr << 'EOF'
#!/bin/bash
case "$1" in
    start)
        systemctl start XrayR
        echo "XrayR đã được khởi động!"
        ;;
    stop)
        systemctl stop XrayR
        echo "XrayR đã dừng!"
        ;;
    restart)
        systemctl restart XrayR
        echo "XrayR đã được khởi động lại!"
        ;;
    status)
        systemctl status XrayR
        ;;
    log)
        journalctl -u XrayR -f -n 50
        ;;
    config)
        nano /etc/XrayR/config.yml || vi /etc/XrayR/config.yml
        ;;
    version)
        /usr/local/XrayR/XrayR -version
        ;;
    *)
        echo "Sử dụng lệnh: xrayr [start|stop|restart|status|log|config|version]"
        ;;
esac
EOF
    chmod +x /usr/bin/xrayr
    ln -sf /usr/bin/xrayr /usr/bin/XrayR
}

# Tạo header config.yml và các file cấu hình phụ trợ
init_config() {
    mkdir -p /etc/XrayR/
    
    # Tạo sẵn custom_outbound.json nếu chưa có
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cat > /etc/XrayR/custom_outbound.json << 'EOF'
[
  {
    "tag": "IPv4_out",
    "protocol": "freedom",
    "settings": {}
  },
  {
    "tag": "IPv6_out",
    "protocol": "freedom",
    "settings": {
      "domainStrategy": "UseIPv6"
    }
  },
  {
    "tag": "socks5-warp",
    "protocol": "socks",
    "settings": {
      "servers": [
        {
          "address": "127.0.0.1",
          "port": 1080
        }
      ]
    }
  },
  {
    "protocol": "blackhole",
    "tag": "block"
  }
]
EOF
    fi

    # Tạo sẵn dns.json nếu chưa có
    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cat > /etc/XrayR/dns.json << 'EOF'
{
  "servers": [
    "1.1.1.1",
    "8.8.8.8",
    "localhost"
  ],
  "tag": "dns_inbound"
}
EOF
    fi

    # Tạo sẵn route.json nếu chưa có
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cat > /etc/XrayR/route.json << 'EOF'
{
  "domainStrategy": "IPOnDemand",
  "rules": [
    {
      "type": "field",
      "outboundTag": "block",
      "ip": [
        "geoip:private"
      ]
    },
    {
      "type": "field",
      "outboundTag": "block",
      "protocol": [
        "bittorrent"
      ]
    },
    {
      "type": "field",
      "outboundTag": "socks5-warp",
      "domain": []
    },
    {
      "type": "field",
      "outboundTag": "IPv6_out",
      "domain": [
        "geosite:netflix"
      ]
    },
    {
      "type": "field",
      "outboundTag": "IPv4_out",
      "network": "udp,tcp"
    }
  ]
}
EOF
    fi

    cat > /etc/XrayR/config.yml <<EOF
Log:
  Level: none
  AccessPath: # /etc/XrayR/access.log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json
RouteConfigPath: # /etc/XrayR/route.json
InboundConfigPath: # /etc/XrayR/custom_inbound.json
OutboundConfigPath: # /etc/XrayR/custom_outbound.json
ConnectionConfig:
  Handshake: 4
  ConnIdle: 30
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64
Nodes:
EOF
}

# Nhập thông tin node và append vào config.yml
add_node_prompt() {
    read -p " Nhập domain web (không cần https://): " api_host
    [ -z "${api_host}" ] && api_host="0"
    api_host=$(echo "$api_host" | sed -e 's|^https://||' -e 's|^http://||' -e 's|/$||')
    echo " -> Web: https://${api_host}"
    echo "--------------------------------"

    read -p " Nhập key web (ApiKey / Token): " api_key
    [ -z "${api_key}" ] && api_key="0"
    echo "--------------------------------"

    echo -e "Chọn kiểu giao thức của Node:"
    echo -e "  ${green}[1] VMess (V2ray)${plain}"
    echo -e "  ${green}[2] VLESS (Hỗ trợ VLESS mới)${plain}"
    echo -e "  ${green}[3] Trojan${plain}"
    read -p "Vui lòng chọn kiểu node [1-3] (mặc định: 1): " choice_type
    [ -z "${choice_type}" ] && choice_type="1"

    if [ "$choice_type" == "2" ]; then
        NodeType="V2ray"
        EnableVless="true"
        echo -e " -> Bạn đã chọn: ${green}VLESS${plain}"
    elif [ "$choice_type" == "3" ]; then
        NodeType="Trojan"
        EnableVless="false"
        echo -e " -> Bạn đã chọn: ${green}Trojan${plain}"
    else
        NodeType="V2ray"
        EnableVless="false"
        echo -e " -> Bạn đã chọn: ${green}VMess (V2ray)${plain}"
    fi
    echo "--------------------------------"

    read -p " Nhập Node ID (ID nút trên web): " node_id
    [ -z "${node_id}" ] && node_id="1"
    echo " -> Node ID: ${node_id}"
    echo "--------------------------------"

    # Lấy IP VPS tự động làm mặc định
    vps_ip=$(curl -s4 ifconfig.me || curl -s4 api.ipify.org || echo "0.0.0.0")
    read -p " Nhập IP VPS hoặc Domain Cert (mặc định: ${vps_ip}): " CertDomain
    [ -z "${CertDomain}" ] && CertDomain="${vps_ip}"
    echo " -> CertDomain: ${CertDomain}"
    echo "--------------------------------"

    # Ghi vào /etc/XrayR/config.yml
    cat >> /etc/XrayR/config.yml <<EOF
  -
    PanelType: "V2board"
    ApiConfig:
      ApiHost: "https://${api_host}"
      ApiKey: "${api_key}"
      NodeID: ${node_id}
      NodeType: ${NodeType}
      Timeout: 30
      EnableVless: ${EnableVless}
      EnableXTLS: false
      SpeedLimit: 0
      DeviceLimit: 0
      RuleListPath:
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriodic: 60
      EnableDNS: false
      DNSType: AsIs
      DisableSniffing: true
      EnableProxyProtocol: false
      EnableFallback: false
      FallBackConfigs:
        -
          SNI:
          Alpn:
          Path:
          Dest: 80
          ProxyProtocolVer: 0
      CertConfig:
        CertMode: file
        CertDomain: "${CertDomain}"
        CertFile: /etc/XrayR/certvpn.crt
        KeyFile: /etc/XrayR/certvpn.key
        Provider: alidns
        Email: test@me.com
        DNSEnv:
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
EOF
}

# Menu thêm n node
batch_add_nodes() {
    read -p "Nhập số lượng node cần thêm (mặc định: 1): " count
    [ -z "${count}" ] && count="1"
    a=0
    while [ $a -lt $count ]; do
        echo -e "\n${yellow}--- Cấu hình Node $((a+1)) / $count ---${plain}"
        add_node_prompt
        a=$((a+1))
    done
}

# Main Menu
clear
echo -e "${green}====================================================${plain}"
echo -e "${green}    TRÌNH CÀI ĐẶT & QUẢN LÝ XRAYR (MOD VLESS MỚI)   ${plain}"
echo -e "${green}    Hỗ trợ VMess / VLESS / Trojan - CertVPN SSL     ${plain}"
echo -e "${green}====================================================${plain}"
echo -e "  ${green}1.${plain} Cài đặt mới XrayR (Tạo lại toàn bộ)"
echo -e "  ${green}2.${plain} Cập nhật lại cấu hình (Xóa cấu hình cũ & nhập lại)"
echo -e "  ${green}3.${plain} Thêm Node mới vào cấu hình hiện tại"
echo -e "  ${green}4.${plain} Khởi động lại XrayR"
echo -e "  ${green}5.${plain} Xem nhật ký XrayR (Log)"
echo -e "  ${green}6.${plain} Gỡ cài đặt XrayR"
echo -e "----------------------------------------------------"
read -p "Vui lòng chọn chức năng [1-6] (mặc định: 1): " opt
[ -z "${opt}" ] && opt="1"

case "${opt}" in
    1)
        clear
        echo -e "${green}>>> BẮT ĐẦU CÀI ĐẶT MỚI XRAYR <<<${plain}"
        install_base
        generate_cert
        install_core
        init_config
        batch_add_nodes
        systemctl restart XrayR
        sleep 2
        echo -e "\n${green}==============================================${plain}"
        echo -e "${green}  Cài đặt XrayR hoàn tất!${plain}"
        echo -e "  Quản lý XrayR: ${yellow}xrayr [start|stop|restart|log|config]${plain}"
        echo -e "${green}==============================================${plain}"
        systemctl status XrayR --no-pager
        ;;
    2)
        clear
        echo -e "${green}>>> CẬP NHẬT LẠI CẤU HÌNH CONFIG.YML <<<${plain}"
        generate_cert
        init_config
        batch_add_nodes
        systemctl restart XrayR
        echo -e "\n${green}Đã cập nhật cấu hình và khởi động lại XrayR!${plain}"
        systemctl status XrayR --no-pager
        ;;
    3)
        clear
        echo -e "${green}>>> THÊM NODE VÀO CẤU HÌNH HIỆN TẠI <<<${plain}"
        generate_cert
        if [[ ! -f /etc/XrayR/config.yml ]]; then
            init_config
        fi
        batch_add_nodes
        systemctl restart XrayR
        echo -e "\n${green}Đã thêm node thành công và khởi động lại XrayR!${plain}"
        systemctl status XrayR --no-pager
        ;;
    4)
        systemctl restart XrayR
        echo -e "${green}Đã khởi động lại XrayR!${plain}"
        systemctl status XrayR --no-pager
        ;;
    5)
        echo -e "${yellow}Nhấn Ctrl+C để thoát xem nhật ký...${plain}"
        journalctl -u XrayR -f -n 50
        ;;
    6)
        read -p "Bạn có chắc chắn muốn gỡ cài đặt XrayR? [y/N]: " confirm_del
        if [[ "$confirm_del" == "y" || "$confirm_del" == "Y" ]]; then
            systemctl stop XrayR 2>/dev/null
            systemctl disable XrayR 2>/dev/null
            rm -f /etc/systemd/system/XrayR.service
            systemctl daemon-reload
            rm -rf /etc/XrayR /usr/local/XrayR /usr/bin/xrayr /usr/bin/XrayR
            echo -e "${green}Đã gỡ cài đặt XrayR sạch sẽ khỏi hệ thống!${plain}"
        else
            echo "Đã hủy bỏ."
        fi
        ;;
    *)
        echo -e "${red}Lựa chọn không hợp lệ!${plain}"
        exit 1
        ;;
esac
