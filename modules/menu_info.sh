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

print_qr_block() {
    local link="$1"; local title="$2"
    echo -e ""; echo -e " ${D}--- ${title} QR Code ---${N}"
    if command -v qrencode &> /dev/null; then qrencode -t ANSIUTF8 -k "${link}" 2>/dev/null || qrencode -t ANSI "${link}"; else echo -e " ${Y}[未安裝 qrencode]${N}"; fi
    echo -e ""
}

p_kv() {
    printf " %b%-26s%b : %b\n" "${C}" "$1" "${N}" "$2"
}

get_node_ip() {
    local ip="${IPV4_ADDR:-${IPV6_ADDR}}"
    echo "$ip"
}

display_links_and_qr() {
    local ip=$(get_node_ip)
    if [[ "$ip" == *":"* ]]; then ip="[${ip}]"; fi
    
    local all_links=""
    
    local node_count=0
    clear; print_banner
    echo -e " ${P}>>> 節點鏈接儀表盤 (Links & QR)${N}"; echo -e "${SEP}"

    if [[ "${PRISM_ENABLE_REALITY_VISION}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. VLESS Reality Vision${N}"
        p_kv "Address" "${Y}${ip}${N}"; p_kv "Port" "${Y}${PRISM_PORT_REALITY_VISION}${N}"
        local link="vless://${PRISM_UUID}@${ip}:${PRISM_PORT_REALITY_VISION}?security=reality&encryption=none&pbk=${PRISM_PUBLIC_KEY}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=${PRISM_DEST}&sid=${PRISM_SHORT_ID}#Prism_Vision"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "Vision"; echo -e "${SEP}"
        all_links+="${link}"$'\n'
    fi

    if [[ "${PRISM_ENABLE_REALITY_GRPC}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. VLESS Reality gRPC${N}"
        p_kv "Address" "${Y}${ip}${N}"; p_kv "Port" "${Y}${PRISM_PORT_REALITY_GRPC}${N}"
        local link="vless://${PRISM_UUID}@${ip}:${PRISM_PORT_REALITY_GRPC}?security=reality&encryption=none&pbk=${PRISM_PUBLIC_KEY}&fp=chrome&type=grpc&serviceName=grpc&sni=${PRISM_DEST}&sid=${PRISM_SHORT_ID}#Prism_gRPC"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "gRPC"; echo -e "${SEP}"
        all_links+="${link}"$'\n'
    fi

    if [[ "${PRISM_ENABLE_HY2}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. Hysteria 2${N}"
        p_kv "Address" "${Y}${ip}${N}"; p_kv "Port" "${Y}${PRISM_PORT_HY2}${N}"
        local sni="www.bing.com"; local insecure="1"
        if [[ "${PRISM_HY2_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni="${PRISM_ACME_DOMAIN}"; insecure="0"; fi
        local link="hysteria2://${PRISM_HY2_PASSWORD}@${ip}:${PRISM_PORT_HY2}?insecure=${insecure}&sni=${sni}#Prism_Hy2"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "Hy2"; echo -e "${SEP}"
        all_links+="${link}"$'\n'
    fi

    if [[ "${PRISM_ENABLE_TUIC}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. TUIC v5${N}"
        p_kv "Address" "${Y}${ip}${N}"; p_kv "Port" "${Y}${PRISM_PORT_TUIC}${N}"
        local sni="www.bing.com"; local insecure="1"
        if [[ "${PRISM_TUIC_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni="${PRISM_ACME_DOMAIN}"; insecure="0"; fi
        local link="tuic://${PRISM_TUIC_UUID}:${PRISM_TUIC_PASSWORD}@${ip}:${PRISM_PORT_TUIC}?congestion_control=bbr&udp_relay_mode=native&allow_insecure=${insecure}&sni=${sni}#Prism_TUIC"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "TUIC"; echo -e "${SEP}"
        all_links+="${link}"$'\n'
    fi

    if [[ "${PRISM_ENABLE_ANYTLS}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. AnyTLS${N}"
        p_kv "Address" "${Y}${ip}${N}"; p_kv "Port" "${Y}${PRISM_PORT_ANYTLS}${N}"
        local sni="www.bing.com"; local insecure="1"
        if [[ "${PRISM_ANYTLS_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni="${PRISM_ACME_DOMAIN}"; insecure="0"; fi
        local link="anytls://prism:${PRISM_ANYTLS_PASSWORD}@${ip}:${PRISM_PORT_ANYTLS}?sni=${sni}&insecure=${insecure}#Prism_AnyTLS"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "AnyTLS"; echo -e "${SEP}"
        all_links+="${link}"$'\n'
    fi

    if [[ "${PRISM_ENABLE_ANYTLS_REALITY}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. AnyTLS + Reality${N}"
        p_kv "Address" "${Y}${ip}${N}"; p_kv "Port" "${Y}${PRISM_PORT_ANYTLS_REALITY}${N}"
        local link="anytls://prism:${PRISM_ANYTLS_REALITY_PASSWORD}@${ip}:${PRISM_PORT_ANYTLS_REALITY}?security=reality&sni=${PRISM_DEST}&pbk=${PRISM_PUBLIC_KEY}&sid=${PRISM_SHORT_ID}&fingerprint=chrome#Prism_AnyReality"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "AnyReality"; echo -e "${SEP}"
        all_links+="${link}"$'\n'
    fi

    if [[ "${PRISM_ENABLE_SHADOWTLS}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}${node_count}. ShadowTLS v3${N}"
        p_kv "Address" "${Y}${ip}${N}"; p_kv "Port" "${Y}${PRISM_PORT_SHADOWTLS}${N}"
        local link="vless://${PRISM_UUID}@${ip}:${PRISM_PORT_SHADOWTLS}?security=shadowtls&encryption=none&type=tcp&sni=${PRISM_DEST}&password=${PRISM_SHADOWTLS_PASSWORD}&version=3#Prism_ShadowTLS"
        echo -e "${W}${link}${N}"; print_qr_block "${link}" "ShadowTLS"; echo -e "${SEP}"
        all_links+="${link}"$'\n'
    fi

    if [[ "$node_count" -eq 0 ]]; then 
        warn "沒有開啟任何節點。"
    else
        if [[ -n "$all_links" ]]; then
            local b64_sub=$(echo -n "$all_links" | base64 | tr -d '\n')
            echo -e " ${P}>>> 🚀 離線訂閱 (Offline Subscription)${N}"
            echo -e " ${D}提示：複製下方字符，在客戶端選擇「從剪貼板導入」即可一次性添加所有節點。${N}"
            echo -e "${SEP}"
            echo -e "${W}${b64_sub}${N}"
            echo -e "${SEP}"
        fi
    fi
    
    read -p " 按回車返回..." 
}

gen_outbound_json_block() {
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
            echo "    { \"type\": \"vless\", \"tag\": \"proxy\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_REALITY_VISION}, \"uuid\": \"${PRISM_UUID}\", \"flow\": \"xtls-rprx-vision\", \"tls\": { \"enabled\": true, \"server_name\": \"${PRISM_DEST}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" }, \"reality\": { \"enabled\": true, \"public_key\": \"${PRISM_PUBLIC_KEY}\", \"short_id\": \"${PRISM_SHORT_ID}\" } }, \"packet_encoding\": \"xudp\" }" ;;
        "grpc")
            echo "    { \"type\": \"vless\", \"tag\": \"proxy\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_REALITY_GRPC}, \"uuid\": \"${PRISM_UUID}\", \"transport\": { \"type\": \"grpc\", \"service_name\": \"grpc\" }, \"tls\": { \"enabled\": true, \"server_name\": \"${PRISM_DEST}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" }, \"reality\": { \"enabled\": true, \"public_key\": \"${PRISM_PUBLIC_KEY}\", \"short_id\": \"${PRISM_SHORT_ID}\" } } }" ;;
        "hy2")
            echo "    { \"type\": \"hysteria2\", \"tag\": \"proxy\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_HY2}, \"password\": \"${PRISM_HY2_PASSWORD}\", \"tls\": { \"enabled\": true, \"server_name\": \"${sni_hy2}\", \"insecure\": ${insecure_hy2}, \"alpn\": [\"h3\"] } }" ;;
        "tuic")
            echo "    { \"type\": \"tuic\", \"tag\": \"proxy\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_TUIC}, \"uuid\": \"${PRISM_TUIC_UUID}\", \"password\": \"${PRISM_TUIC_PASSWORD}\", \"congestion_control\": \"bbr\", \"udp_relay_mode\": \"native\", \"tls\": { \"enabled\": true, \"server_name\": \"${sni_tuic}\", \"insecure\": ${insecure_tuic}, \"alpn\": [\"h3\"] } }" ;;
        "anytls")
            echo "    { \"type\": \"anytls\", \"tag\": \"proxy\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_ANYTLS}, \"users\": [{ \"name\": \"prism\", \"password\": \"${PRISM_ANYTLS_PASSWORD}\" }], \"tls\": { \"enabled\": true, \"server_name\": \"${sni_any}\", \"insecure\": ${insecure_any} } }" ;;
        "anyreality")
            echo "    { \"type\": \"anytls\", \"tag\": \"proxy\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_ANYTLS_REALITY}, \"users\": [{ \"name\": \"prism\", \"password\": \"${PRISM_ANYTLS_REALITY_PASSWORD}\" }], \"tls\": { \"enabled\": true, \"server_name\": \"${PRISM_DEST}\", \"reality\": { \"enabled\": true, \"public_key\": \"${PRISM_PUBLIC_KEY}\", \"short_id\": \"${PRISM_SHORT_ID}\" }, \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" } } }" ;;
        "shadowtls")
            echo "    { \"type\": \"shadowtls\", \"tag\": \"shadowtls-out\", \"server\": \"${ip}\", \"server_port\": ${PRISM_PORT_SHADOWTLS}, \"version\": 3, \"password\": \"${PRISM_SHADOWTLS_PASSWORD}\", \"tls\": { \"enabled\": true, \"server_name\": \"${PRISM_DEST}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" } } },"
            echo "    { \"type\": \"vless\", \"tag\": \"proxy\", \"detour\": \"shadowtls-out\", \"uuid\": \"${PRISM_UUID}\", \"flow\": \"\" }" ;;
        *) echo "{}" ;;
    esac
}

display_client_json() {
    while true; do
        clear; print_banner
        echo -e " ${P}>>> 生成客戶端配置 (Client JSON)${N}"; echo -e "${SEP}"
        
        local options=(); local index=1
        add_opt() { if [[ "${!2}" == "true" ]]; then echo -e "  ${P}${index}.${N} ${W}$1${N}"; options[index]="$3"; ((index++)); fi; }
        
        add_opt "VLESS Reality Vision" "PRISM_ENABLE_REALITY_VISION" "vision"
        add_opt "VLESS Reality gRPC"   "PRISM_ENABLE_REALITY_GRPC"   "grpc"
        add_opt "Hysteria 2"           "PRISM_ENABLE_HY2"            "hy2"
        add_opt "TUIC v5"              "PRISM_ENABLE_TUIC"           "tuic"
        add_opt "AnyTLS (Native)"      "PRISM_ENABLE_ANYTLS"         "anytls"
        add_opt "AnyTLS + Reality"     "PRISM_ENABLE_ANYTLS_REALITY" "anyreality"
        add_opt "ShadowTLS v3"         "PRISM_ENABLE_SHADOWTLS"      "shadowtls"
        
        if [[ "$index" -eq 1 ]]; then echo -e " ${Y}無可用節點${N}"; read -p "..."; return; fi
        
        echo -e "${SEP}"; echo -e "  ${P}0.${N} 返回"; echo -e "${SEP}"; echo -ne " 請選擇協議: "; read -r p_choice
        
        if [[ "$p_choice" == "0" ]]; then return; fi
        local target_proto="${options[p_choice]}"
        
        if [[ -n "$target_proto" ]]; then
            local outbound_block=$(gen_outbound_json_block "$target_proto")
            
            clear; echo -e "${G}>>> 複製以下內容保存為 config.json:${N}"; echo -e "${SEP}"
            
            cat <<EOF
{
  "log": { "level": "info", "timestamp": true },
  "dns": { 
    "servers": [ 
      { "tag": "google", "address": "8.8.8.8", "detour": "proxy" }, 
      { "tag": "local", "address": "223.5.5.5", "detour": "direct" } 
    ], 
    "rules": [ { "outbound": "any", "server": "local" } ] 
  },
  "inbounds": [ 
    { "type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 2080, "sniff": true } 
  ],
  "outbounds": [
$outbound_block,
    { "type": "direct", "tag": "direct" }, 
    { "type": "block", "tag": "block" }
  ],
  "route": { "auto_detect_interface": true, "final": "proxy" }
}
EOF
            echo -e "${SEP}"; read -p " 按回車返回..."
        else
            error "無效選擇"; sleep 1
        fi
    done
}

show_node_info() {
    if [[ ! -f "${CONFIG_DIR}/secrets.env" ]]; then error "配置丟失"; read -p "..."; show_menu; return; fi
    source "${CONFIG_DIR}/secrets.env"
    
    while true; do
        clear; print_banner
        echo -e " ${P}>>> 節點信息 (Node Information)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}查看 鏈接 & 二維碼${N}  ${D}(All-in-One)${N}"
        echo -e "  ${P}2.${N} ${W}獲取 客戶端配置${N}     ${D}(Stand-alone JSON)${N}"
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
