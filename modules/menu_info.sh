#!/usr/bin/env bash

# Copyright (C) 2025 Yat-muk <https://github.com/Yat-Muk/prism>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

source "${BASE_DIR}/core/env.sh"
source "${BASE_DIR}/core/ui.sh"

declare -a LINK_POOL
declare -a JSON_OUTBOUNDS
declare -a PROXY_TAGS


print_qr_block() {
    local link="$1"; local title="$2"
    echo -e ""; echo -e " ${D}--- ${title} QR Code ---${N}"
    if command -v qrencode &> /dev/null; then qrencode -t ANSIUTF8 -k "${link}" 2>/dev/null || qrencode -t ANSI "${link}"; else echo -e " ${Y}[未安裝 qrencode]${N}"; fi
    echo -e ""
}

p_kv() {
    local key="$1"; local val="$2"; local width=20
    local padding=$(awk -v str="$key" -v w="$width" 'BEGIN {
        len = length(str); non_ascii = 0;
        for(i=1; i<=len; i++) { if(substr(str,i,1) ~ /[^\x00-\x7F]/) non_ascii++; }
        display_width = len + non_ascii; pad_len = w - display_width;
        if(pad_len < 0) pad_len = 0; printf "%*s", pad_len, "";
    }')
    echo -e " ${C}${key}${N}${padding} : ${W}${val}${N}"
}

get_node_ip() {
    local ip="${IPV4_ADDR:-${IPV6_ADDR}}"
    echo "$ip"
}

display_links_and_qr() {
    LINK_POOL=()
    local ip=$(get_node_ip)
    local ip_url="$ip"
    if [[ "$ip" == *":"* ]]; then ip_url="[${ip}]"; fi
    
    local node_count=0
    clear; print_banner
    echo -e " ${P}>>> 節點詳細信息 (Node Dashboard)${N}"
    echo -e " ${D}提示：參數已標準化，頁面底部包含離線訂閱碼。${N}"
    echo -e "${SEP}"

    if [[ "${PRISM_ENABLE_REALITY_VISION}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. VLESS Reality Vision${N} ${D}[TCP]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_REALITY_VISION}${N}"
        p_kv "UUID (用戶ID)"       "${W}${PRISM_UUID}${N}"
        p_kv "Flow (流控)"         "xtls-rprx-vision"
        p_kv "Network (傳輸)"      "tcp"
        p_kv "SNI (偽裝域名)"      "${W}${PRISM_DEST}${N}"
        p_kv "Fingerprint (指紋)"  "chrome"
        p_kv "PublicKey (公鑰)"    "${Y}${PRISM_PUBLIC_KEY}${N}"
        p_kv "ShortID (簡碼)"      "${PRISM_SHORT_ID}"
        
        local link="vless://${PRISM_UUID}@${ip_url}:${PRISM_PORT_REALITY_VISION}?security=reality&encryption=none&pbk=${PRISM_PUBLIC_KEY}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=${PRISM_DEST}&sid=${PRISM_SHORT_ID}#Prism_Vision"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "Vision"
        echo -e "${SEP}"
        LINK_POOL+=("$link")
    fi

    if [[ "${PRISM_ENABLE_REALITY_GRPC}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. VLESS Reality gRPC${N} ${D}[gRPC]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_REALITY_GRPC}${N}"
        p_kv "UUID (用戶ID)"       "${W}${PRISM_UUID}${N}"
        p_kv "Network (傳輸)"      "grpc"
        p_kv "ServiceName (服務名)" "grpc"
        p_kv "SNI (偽裝域名)"      "${W}${PRISM_DEST}${N}"
        p_kv "PublicKey (公鑰)"    "${Y}${PRISM_PUBLIC_KEY}${N}"
        p_kv "ShortID (簡碼)"      "${PRISM_SHORT_ID}"
        
        local link="vless://${PRISM_UUID}@${ip_url}:${PRISM_PORT_REALITY_GRPC}?security=reality&encryption=none&pbk=${PRISM_PUBLIC_KEY}&fp=chrome&type=grpc&serviceName=grpc&sni=${PRISM_DEST}&sid=${PRISM_SHORT_ID}#Prism_gRPC"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "gRPC"
        echo -e "${SEP}"
        LINK_POOL+=("$link")
    fi

    if [[ "${PRISM_ENABLE_HY2}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. Hysteria 2${N} ${D}[UDP]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        local port_display="${PRISM_PORT_HY2}"
        if [[ -n "${PRISM_HY2_PORT_HOPPING}" ]]; then
            port_display="${PRISM_PORT_HY2} (跳躍: ${PRISM_HY2_PORT_HOPPING//-/:})"
        fi
        p_kv "Port (端口)"         "${Y}${port_display}${N}"
        p_kv "Auth (認證類型)"     "password"
        p_kv "Password (密碼)"     "${W}${PRISM_HY2_PASSWORD}${N}"
        
        local sni="www.bing.com"; local insecure_val="1"; local cert_status="${R}自簽名 (Self-signed)${N}"; local insecure_display="${Y}True${N}"
        if [[ "${PRISM_HY2_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni="${PRISM_ACME_DOMAIN}"; insecure_val="0"; cert_status="${G}ACME (Valid)${N}"; insecure_display="${G}False${N}"; fi
        
        p_kv "SNI (偽裝域名)"      "${W}${sni}${N}"
        p_kv "Cert Mode (證書模式)" "${cert_status}"
        p_kv "Insecure (跳過驗證)" "${insecure_display}"
        p_kv "ALPN"                "h3"
        
        local link="hysteria2://${PRISM_HY2_PASSWORD}@${ip_url}:${PRISM_PORT_HY2}?insecure=${insecure_val}&sni=${sni}#Prism_Hy2"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "Hy2"
        echo -e "${SEP}"
        LINK_POOL+=("$link")
    fi

    if [[ "${PRISM_ENABLE_TUIC}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. TUIC v5${N} ${D}[QUIC]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        local port_display="${PRISM_PORT_TUIC}"
        if [[ -n "${PRISM_TUIC_PORT_HOPPING}" ]]; then
            port_display="${PRISM_PORT_TUIC} (跳躍: ${PRISM_TUIC_PORT_HOPPING//-/:})"
        fi
        p_kv "Port (端口)"         "${Y}${port_display}${N}"
        p_kv "UUID (用戶ID)"       "${W}${PRISM_TUIC_UUID}${N}"
        p_kv "Password (密碼)"     "${W}${PRISM_TUIC_PASSWORD}${N}"
        p_kv "Congestion (擁塞)"   "bbr"
        p_kv "UDP Relay (轉發)"    "native"
        
        local sni="www.bing.com"; local insecure_val="1"; local cert_status="${R}自簽名 (Self-signed)${N}"; local insecure_display="${Y}True${N}"
        if [[ "${PRISM_TUIC_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni="${PRISM_ACME_DOMAIN}"; insecure_val="0"; cert_status="${G}ACME (Valid)${N}"; insecure_display="${G}False${N}"; fi
        
        p_kv "SNI (偽裝域名)"      "${W}${sni}${N}"
        p_kv "Cert Mode (證書模式)" "${cert_status}"
        p_kv "Insecure (跳過驗證)" "${insecure_display}"
        p_kv "ALPN"                "h3"
        
        local link="tuic://${PRISM_TUIC_UUID}:${PRISM_TUIC_PASSWORD}@${ip_url}:${PRISM_PORT_TUIC}?congestion_control=bbr&udp_relay_mode=native&allow_insecure=${insecure_val}&sni=${sni}#Prism_TUIC"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "TUIC"
        echo -e "${SEP}"
        LINK_POOL+=("$link")
    fi

    if [[ "${PRISM_ENABLE_ANYTLS}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. AnyTLS${N} ${D}[AnyTLS Protocol]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_ANYTLS}${N}"
        p_kv "User (用戶名)"       "prism"
        p_kv "Password (密碼)"     "${W}${PRISM_ANYTLS_PASSWORD}${N}"
        
        local sni="www.bing.com"; local insecure_val="1"; local cert_status="${R}自簽名${N}"; local insecure_display="${Y}True${N}"
        if [[ "${PRISM_ANYTLS_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni="${PRISM_ACME_DOMAIN}"; insecure_val="0"; cert_status="${G}ACME${N}"; insecure_display="${G}False${N}"; fi
        
        p_kv "SNI (偽裝域名)"      "${W}${sni}${N}"
        p_kv "Cert Mode (證書模式)" "${cert_status}"
        p_kv "Insecure (跳過驗證)" "${insecure_display}"
        
        local link="anytls://prism:${PRISM_ANYTLS_PASSWORD}@${ip_url}:${PRISM_PORT_ANYTLS}?sni=${sni}&insecure=${insecure_val}#Prism_AnyTLS"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "AnyTLS"
        echo -e "${SEP}"
        LINK_POOL+=("$link")
    fi

    if [[ "${PRISM_ENABLE_ANYTLS_REALITY}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. AnyTLS + Reality${N} ${D}[AnyTLS Protocol]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_ANYTLS_REALITY}${N}"
        p_kv "User (用戶名)"       "prism"
        p_kv "Password (密碼)"     "${W}${PRISM_ANYTLS_REALITY_PASSWORD}${N}"
        p_kv "SNI (偽裝域名)"      "${W}${PRISM_DEST}${N}"
        p_kv "PublicKey (公鑰)"    "${Y}${PRISM_PUBLIC_KEY}${N}"
        p_kv "ShortID (簡碼)"      "${PRISM_SHORT_ID}"
        p_kv "Fingerprint (指紋)"  "chrome"
        
        local link="anytls://prism:${PRISM_ANYTLS_REALITY_PASSWORD}@${ip_url}:${PRISM_PORT_ANYTLS_REALITY}?security=reality&sni=${PRISM_DEST}&pbk=${PRISM_PUBLIC_KEY}&sid=${PRISM_SHORT_ID}&fingerprint=chrome#Prism_AnyReality"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "AnyReality"
        echo -e "${SEP}"
        LINK_POOL+=("$link")
    fi

    if [[ "${PRISM_ENABLE_SHADOWTLS}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. ShadowTLS v3${N} ${D}[SS-2022+Wrapper]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_SHADOWTLS}${N}"
        p_kv "Handshake (握手域名)" "${W}${PRISM_DEST}${N}"
        p_kv "ShadowTLS Pwd (偽裝密碼)" "${W}${PRISM_SHADOWTLS_PASSWORD}${N}"
        p_kv "Inner Proto (內層協議)" "SS-2022 (blake3-aes-128-gcm)"
        p_kv "SS Password (加密密碼)" "${Y}${PRISM_SS_PASSWORD}${N}"
        
        local ss_auth=$(echo -n "2022-blake3-aes-128-gcm:${PRISM_SS_PASSWORD}" | base64 | tr -d '\n')
        local link="ss://${ss_auth}@${ip_url}:${PRISM_PORT_SHADOWTLS}?plugin=shadow-tls%3Bserver%3D${PRISM_DEST}%3Bpassword%3D${PRISM_SHADOWTLS_PASSWORD}%3Bversion%3D3#Prism_ShadowTLS"
        
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "ShadowTLS"
        echo -e "${SEP}"
        LINK_POOL+=("$link")
    fi

    if [[ "$node_count" -eq 0 ]]; then 
        warn "沒有開啟任何節點。"
    else
        local all_links_str=$(printf "%s\n" "${LINK_POOL[@]}")
        local b64_sub=$(echo -n "$all_links_str" | base64 | tr -d '\n')
        echo -e " ${P}>>> 🚀 離線訂閱 (Offline Subscription)${N}"
        echo -e " ${D}提示：複製下方字符串，在客戶端選擇 ${W}「從剪貼板導入」${D} 即可。${N}"
        echo -e "${SEP}"
        echo -e "${W}${b64_sub}${N}"
        echo -e "${SEP}"
    fi
    read -p " 按回車返回主菜單..." 
    show_menu
}

generate_json_outbound_object() {
    local proto=$1
    local ip=$(get_node_ip)
    local sni_hy2="www.bing.com"; local insecure_hy2=true
    if [[ "${PRISM_HY2_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni_hy2="${PRISM_ACME_DOMAIN}"; insecure_hy2=false; fi
    local sni_tuic="www.bing.com"; local insecure_tuic=true
    if [[ "${PRISM_TUIC_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni_tuic="${PRISM_ACME_DOMAIN}"; insecure_tuic=false; fi
    local sni_any="www.bing.com"; local insecure_any=true
    if [[ "${PRISM_ANYTLS_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni_any="${PRISM_ACME_DOMAIN}"; insecure_any=false; fi

    case "$proto" in
        "vision")
            echo "{ \"type\": \"vless\", \"tag\": \"Vision\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_REALITY_VISION}, \"uuid\": \"${PRISM_UUID}\", \"flow\": \"xtls-rprx-vision\", \"tls\": { \"enabled\": true, \"server_name\": \"${PRISM_DEST}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" }, \"reality\": { \"enabled\": true, \"public_key\": \"${PRISM_PUBLIC_KEY}\", \"short_id\": \"${PRISM_SHORT_ID}\" } }, \"packet_encoding\": \"xudp\" }" ;;
        "grpc")
            echo "{ \"type\": \"vless\", \"tag\": \"gRPC\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_REALITY_GRPC}, \"uuid\": \"${PRISM_UUID}\", \"transport\": { \"type\": \"grpc\", \"service_name\": \"grpc\" }, \"tls\": { \"enabled\": true, \"server_name\": \"${PRISM_DEST}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" }, \"reality\": { \"enabled\": true, \"public_key\": \"${PRISM_PUBLIC_KEY}\", \"short_id\": \"${PRISM_SHORT_ID}\" } } }" ;;
        "hy2")
            local hy2_port_val=${PRISM_PORT_HY2}
            if [[ -n "${PRISM_HY2_PORT_HOPPING}" ]]; then
                hy2_port_val="\"${PRISM_HY2_PORT_HOPPING//-/:}\""
            fi
            echo "{ \"type\": \"hysteria2\", \"tag\": \"Hy2\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_HY2}, \"password\": \"${PRISM_HY2_PASSWORD}\", \"tls\": { \"enabled\": true, \"server_name\": \"${sni_hy2}\", \"insecure\": ${insecure_hy2}, \"alpn\": [\"h3\"] } }" ;;
        "tuic")
            echo "{ \"type\": \"tuic\", \"tag\": \"TUIC\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_TUIC}, \"uuid\": \"${PRISM_TUIC_UUID}\", \"password\": \"${PRISM_TUIC_PASSWORD}\", \"congestion_control\": \"bbr\", \"udp_relay_mode\": \"native\", \"tls\": { \"enabled\": true, \"server_name\": \"${sni_tuic}\", \"insecure\": ${insecure_tuic}, \"alpn\": [\"h3\"] } }" ;;
        "anytls")
            echo "{ \"type\": \"anytls\", \"tag\": \"AnyTLS\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_ANYTLS}, \"users\": [{ \"name\": \"prism\", \"password\": \"${PRISM_ANYTLS_PASSWORD}\" }], \"tls\": { \"enabled\": true, \"server_name\": \"${sni_any}\", \"insecure\": ${insecure_any} } }" ;;
        "anyreality")
            echo "{ \"type\": \"anytls\", \"tag\": \"AnyReality\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_ANYTLS_REALITY}, \"users\": [{ \"name\": \"prism\", \"password\": \"${PRISM_ANYTLS_REALITY_PASSWORD}\" }], \"tls\": { \"enabled\": true, \"server_name\": \"${PRISM_DEST}\", \"reality\": { \"enabled\": true, \"public_key\": \"${PRISM_PUBLIC_KEY}\", \"short_id\": \"${PRISM_SHORT_ID}\" }, \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" } } }" ;;
        "shadowtls")
            echo "{ \"type\": \"shadowtls\", \"tag\": \"ShadowTLS-Out\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_SHADOWTLS}, \"version\": 3, \"password\": \"${PRISM_SHADOWTLS_PASSWORD}\", \"tls\": { \"enabled\": true, \"server_name\": \"${PRISM_DEST}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" } } }" 
            ;;
    esac
}

display_client_json() {
    clear; print_banner
    echo -e " ${P}>>> 客戶端完整配置 (Aggregated Config)${N}"
    echo -e " ${D}提示：此配置包含所有可用節點，複製保存為 config.json 即可使用。${N}"
    echo -e "${SEP}"

    JSON_OUTBOUNDS=()
    PROXY_TAGS=()

    if [[ "${PRISM_ENABLE_REALITY_VISION}" == "true" ]]; then
        JSON_OUTBOUNDS+=("$(generate_json_outbound_object "vision")"); PROXY_TAGS+=("\"Vision\"")
    fi
    if [[ "${PRISM_ENABLE_REALITY_GRPC}" == "true" ]]; then
        JSON_OUTBOUNDS+=("$(generate_json_outbound_object "grpc")"); PROXY_TAGS+=("\"gRPC\"")
    fi
    if [[ "${PRISM_ENABLE_HY2}" == "true" ]]; then
        JSON_OUTBOUNDS+=("$(generate_json_outbound_object "hy2")"); PROXY_TAGS+=("\"Hy2\"")
    fi
    if [[ "${PRISM_ENABLE_TUIC}" == "true" ]]; then
        JSON_OUTBOUNDS+=("$(generate_json_outbound_object "tuic")"); PROXY_TAGS+=("\"TUIC\"")
    fi
    if [[ "${PRISM_ENABLE_ANYTLS}" == "true" ]]; then
        JSON_OUTBOUNDS+=("$(generate_json_outbound_object "anytls")"); PROXY_TAGS+=("\"AnyTLS\"")
    fi
    if [[ "${PRISM_ENABLE_ANYTLS_REALITY}" == "true" ]]; then
        JSON_OUTBOUNDS+=("$(generate_json_outbound_object "anyreality")"); PROXY_TAGS+=("\"AnyReality\"")
    fi
    if [[ "${PRISM_ENABLE_SHADOWTLS}" == "true" ]]; then
        JSON_OUTBOUNDS+=("$(generate_json_outbound_object "shadowtls")")
        JSON_OUTBOUNDS+=("{ \"type\": \"shadowsocks\", \"tag\": \"ShadowTLS\", \"detour\": \"ShadowTLS-Out\", \"method\": \"2022-blake3-aes-128-gcm\", \"password\": \"${PRISM_SS_PASSWORD}\" }")
        PROXY_TAGS+=("\"ShadowTLS\"")
    fi

    if [[ ${#PROXY_TAGS[@]} -eq 0 ]]; then warn "無可用節點"; read -p "..."; return; fi

    local tags_string=$(IFS=,; echo "${PROXY_TAGS[*]}")
    local all_nodes_json=$(IFS=,; echo "${JSON_OUTBOUNDS[*]}")

    cat > "${WORK_DIR}/temp_client.json" <<EOF
{
  "log": { "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "tag": "google", "address": "8.8.8.8", "detour": "🚀 節點選擇" },
      { "tag": "local", "address": "223.5.5.5", "detour": "direct" }
    ],
    "rules": [ { "outbound": "any", "server": "local" } ]
  },
  "inbounds": [
    { "type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 2080, "sniff": true }
  ],
  "outbounds": [
    {
      "type": "selector",
      "tag": "🚀 節點選擇",
      "outbounds": [ "⚡ 自動選擇", ${tags_string}, "direct" ]
    },
    {
      "type": "urltest",
      "tag": "⚡ 自動選擇",
      "outbounds": [ ${tags_string} ],
      "url": "http://www.gstatic.com/generate_204",
      "interval": "3m"
    },
    ${all_nodes_json},
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "auto_detect_interface": true,
    "final": "🚀 節點選擇"
  }
}
EOF

    if command -v jq &> /dev/null; then
        jq . "${WORK_DIR}/temp_client.json"
    else
        cat "${WORK_DIR}/temp_client.json"
    fi
    rm -f "${WORK_DIR}/temp_client.json"

    echo -e "${SEP}"
    read -p " 按回車返回主菜單..."
    show_menu
}

show_node_info() {
    if [[ ! -f "${CONFIG_DIR}/secrets.env" ]]; then error "配置丟失"; read -p "..."; show_menu; return; fi
    source "${CONFIG_DIR}/secrets.env"
    
    while true; do
        clear; print_banner
        echo -e " ${P}>>> 節點信息 (Node Information)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}查看 鏈接 & 訂閱${N}  ${D}(離線訂閱 & 二維碼)${N}"
        echo -e "  ${P}2.${N} ${W}獲取 客戶端配置${N}   ${D}(完整 JSON 配置)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回主菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        
        case "$choice" in
            1) display_links_and_qr ;;
            2) display_client_json ;;
            0) show_menu; break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
}
