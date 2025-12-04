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
    local link="$1"
    local title="$2"
    
    echo -e ""
    echo -e " ${D}--- ${title} QR Code (二維碼) ---${N}"
    if command -v qrencode &> /dev/null; then
        qrencode -t ANSIUTF8 -k "${link}" 2>/dev/null || qrencode -t ANSI "${link}"
    else
        echo -e " ${Y}[未安裝 qrencode，無法顯示二維碼]${N}"
    fi
    echo -e ""
}

p_kv() {
    local key="$1"
    local val="$2"
    
    local width=20
    
    local padding=$(awk -v str="$key" -v w="$width" 'BEGIN {
        len = length(str);
        non_ascii = 0;
        for(i=1; i<=len; i++) {
            if(substr(str,i,1) ~ /[^\x00-\x7F]/) non_ascii++;
        }
        display_width = len + non_ascii;
        pad_len = w - display_width;
        if(pad_len < 0) pad_len = 0;
        printf "%*s", pad_len, "";
    }')
    
    echo -e " ${C}${key}${N}${padding} : ${W}${val}${N}"
}

show_node_info() {
    if [[ ! -f "${CONFIG_DIR}/secrets.env" ]]; then 
        error "配置文件不存在 (Config missing)"
        read -p " 按回車返回..." 
        show_menu; return
    fi
    source "${CONFIG_DIR}/secrets.env"
    
    if [[ -z "${PRISM_UUID}" ]]; then
        error "配置數據不完整 (Incomplete data)"
        read -p " 按回車返回..." 
        show_menu; return
    fi

    local ip="${IPV4_ADDR:-${IPV6_ADDR}}"
    if [[ "$ip" == *":"* ]]; then ip="[${ip}]"; fi
    
    clear; print_banner
    echo -e " ${P}>>> 節點配置儀表盤 (Node Dashboard)${N}"
    echo -e " ${D}提示：信息已轉化為客戶端通用格式 (True/False)${N}"
    echo -e "${SEP}"

    local node_count=0

    if [[ "${PRISM_ENABLE_REALITY_VISION}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}1. VLESS Reality Vision${N} ${D}[TCP]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_REALITY_VISION}${N}"
        p_kv "UUID (用戶ID)"       "${W}${PRISM_UUID}${N}"
        p_kv "Flow (流控)"         "xtls-rprx-vision"
        p_kv "Network (傳輸)"      "tcp"
        p_kv "SNI (偽裝域名)"      "${W}${PRISM_DEST}${N}"
        p_kv "Fingerprint (指紋)"  "chrome"
        p_kv "PublicKey (公鑰)"    "${Y}${PRISM_PUBLIC_KEY}${N}"
        p_kv "ShortID (簡碼)"      "${PRISM_SHORT_ID}"
        
        local link="vless://${PRISM_UUID}@${ip}:${PRISM_PORT_REALITY_VISION}?security=reality&encryption=none&pbk=${PRISM_PUBLIC_KEY}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=${PRISM_DEST}&sid=${PRISM_SHORT_ID}#Prism_Vision"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"
        print_qr_block "${link}" "Vision"
        echo -e "${SEP}"
    fi

    if [[ "${PRISM_ENABLE_REALITY_GRPC}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}2. VLESS Reality gRPC${N} ${D}[gRPC]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_REALITY_GRPC}${N}"
        p_kv "UUID (用戶ID)"       "${W}${PRISM_UUID}${N}"
        p_kv "Network (傳輸)"      "grpc"
        p_kv "ServiceName (服務名)" "grpc"
        p_kv "SNI (偽裝域名)"      "${W}${PRISM_DEST}${N}"
        p_kv "PublicKey (公鑰)"    "${Y}${PRISM_PUBLIC_KEY}${N}"
        p_kv "ShortID (簡碼)"      "${PRISM_SHORT_ID}"
        
        local link="vless://${PRISM_UUID}@${ip}:${PRISM_PORT_REALITY_GRPC}?security=reality&encryption=none&pbk=${PRISM_PUBLIC_KEY}&fp=chrome&type=grpc&serviceName=grpc&sni=${PRISM_DEST}&sid=${PRISM_SHORT_ID}#Prism_gRPC"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"
        print_qr_block "${link}" "gRPC"
        echo -e "${SEP}"
    fi

    if [[ "${PRISM_ENABLE_HY2}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}3. Hysteria 2${N} ${D}[UDP]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        
        local port_display="${PRISM_PORT_HY2}"
        if [[ -n "${PRISM_HY2_PORT_HOPPING}" ]]; then
            port_display="${PRISM_PORT_HY2} (跳躍: ${PRISM_HY2_PORT_HOPPING})"
        fi
        p_kv "Port (端口)"         "${Y}${port_display}${N}"
        p_kv "Auth (認證類型)"     "password"
        p_kv "Password (密碼)"     "${W}${PRISM_HY2_PASSWORD}${N}"
        
        local sni="www.bing.com"
        local insecure_val="1"
        local insecure_display="${Y}True${N}"
        local cert_status="${R}自簽名 (Self-signed)${N}"
        
        if [[ "${PRISM_HY2_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then
            sni="${PRISM_ACME_DOMAIN}"
            insecure_val="0"
            cert_status="${G}ACME 證書 (Valid)${N}"
            insecure_display="${G}False${N}"
        fi
        
        p_kv "SNI (偽裝域名)"          "${W}${sni}${N}"
        p_kv "Cert Mode (證書模式)"    "${cert_status}"
        p_kv "Insecure (跳過驗證)"  "${insecure_display}"

        local link="hysteria2://${PRISM_HY2_PASSWORD}@${ip}:${PRISM_PORT_HY2}?insecure=${insecure_val}&sni=${sni}#Prism_Hy2"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"
        print_qr_block "${link}" "Hy2"
        echo -e "${SEP}"
    fi

    if [[ "${PRISM_ENABLE_TUIC}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}4. TUIC v5${N} ${D}[QUIC]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        
        local port_display="${PRISM_PORT_TUIC}"
        if [[ -n "${PRISM_TUIC_PORT_HOPPING}" ]]; then
            port_display="${PRISM_PORT_TUIC} (跳躍: ${PRISM_TUIC_PORT_HOPPING})"
        fi
        p_kv "Port (端口)"         "${Y}${port_display}${N}"
        p_kv "UUID (用戶ID)"       "${W}${PRISM_TUIC_UUID}${N}"
        p_kv "Password (密碼)"     "${W}${PRISM_TUIC_PASSWORD}${N}"
        p_kv "Congestion (擁塞)"   "bbr"
        p_kv "UDP Relay (轉發)"    "native"
        
        local sni="www.bing.com"
        local insecure_val="1"
        local insecure_display="${Y}True${N}"
        local cert_status="${R}自簽名 (Self-signed)${N}"
        
        if [[ "${PRISM_TUIC_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then
            sni="${PRISM_ACME_DOMAIN}"
            insecure_val="0"
            cert_status="${G}ACME 證書 (Valid)${N}"
            insecure_display="${G}False${N}"
        fi
        p_kv "SNI (偽裝域名)"          "${W}${sni}${N}"
        p_kv "Cert Mode (證書模式)"    "${cert_status}"
        p_kv "Insecure (跳過驗證)"  "${insecure_display}"

        local link="tuic://${PRISM_TUIC_UUID}:${PRISM_TUIC_PASSWORD}@${ip}:${PRISM_PORT_TUIC}?congestion_control=bbr&udp_relay_mode=native&allow_insecure=${insecure_val}&sni=${sni}#Prism_TUIC"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"
        print_qr_block "${link}" "TUIC"
        echo -e "${SEP}"
    fi

    if [[ "${PRISM_ENABLE_ANYTLS}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}5. AnyTLS${N} ${D}[Native TLS]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_ANYTLS}${N}"
        p_kv "Password (密碼)"     "${W}${PRISM_ANYTLS_PASSWORD}${N}"
        
        local sni="www.bing.com"
        local insecure_val="1"
        local insecure_display="${Y}True${N}"
        
        if [[ "${PRISM_ANYTLS_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then
            sni="${PRISM_ACME_DOMAIN}"
            insecure_val="0"
            insecure_display="${G}False${N}"
        fi
        p_kv "SNI (偽裝域名)"          "${W}${sni}${N}"
        p_kv "Insecure (跳過驗證)"  "${insecure_display}"
        
        local link="anytls://${PRISM_ANYTLS_PASSWORD}@${ip}:${PRISM_PORT_ANYTLS}?sni=${sni}&insecure=${insecure_val}&peer=${sni}#Prism_AnyTLS"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"
        print_qr_block "${link}" "AnyTLS"
        echo -e "${SEP}"
    fi

    if [[ "${PRISM_ENABLE_ANYTLS_REALITY}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}6. AnyTLS + Reality${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_ANYTLS_REALITY}${N}"
        p_kv "Password (密碼)"     "${W}${PRISM_ANYTLS_REALITY_PASSWORD}${N}"
        p_kv "SNI (偽裝域名)"      "${W}${PRISM_DEST}${N}"
        p_kv "PublicKey (公鑰)"    "${Y}${PRISM_PUBLIC_KEY}${N}"
        p_kv "ShortID (簡碼)"      "${PRISM_SHORT_ID}"
        p_kv "Fingerprint (指紋)"  "chrome"
        
        local link="anytls://${PRISM_ANYTLS_REALITY_PASSWORD}@${ip}:${PRISM_PORT_ANYTLS_REALITY}?security=reality&sni=${PRISM_DEST}&pbk=${PRISM_PUBLIC_KEY}&sid=${PRISM_SHORT_ID}&fingerprint=chrome#Prism_AnyTLS_Reality"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"
        print_qr_block "${link}" "AnyReality"
        echo -e "${SEP}"
    fi
    
    if [[ "${PRISM_ENABLE_SHADOWTLS}" == "true" ]]; then
        ((node_count++))
        echo -e " ${G}7. ShadowTLS v3${N} ${D}[Wrapper]${N}"
        p_kv "Address (地址)"      "${Y}${ip}${N}"
        p_kv "Port (端口)"         "${Y}${PRISM_PORT_SHADOWTLS}${N}"
        p_kv "Password (密碼)"     "${W}${PRISM_SHADOWTLS_PASSWORD}${N}"
        p_kv "Handshake (握手域名)" "${W}${PRISM_DEST}${N}"
        p_kv "Version (版本)"      "3"
        
        local link="vless://${PRISM_UUID}@${ip}:${PRISM_PORT_SHADOWTLS}?security=shadowtls&encryption=none&type=tcp&sni=${PRISM_DEST}&password=${PRISM_SHADOWTLS_PASSWORD}&version=3#Prism_ShadowTLS"
        echo -e " ${D}---------------------------------------------------------${N}"
        echo -e "${W}${link}${N}"
        print_qr_block "${link}" "ShadowTLS"
        echo -e "${SEP}"
    fi

    if [[ "$node_count" -eq 0 ]]; then
        echo -e " ${Y}當前沒有開啟任何協議節點 (No active protocols)。${N}"
        echo -e " 請前往 [4. 配置與協議管理] -> [1. 協議管理] 開啟。"
        echo -e "${SEP}"
    fi

    read -p " 按回車返回菜單 (Press Enter to return)..."
    show_menu
}
