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

print_qr_block() {
    local link="$1"
    if command -v qrencode &> /dev/null; then
        echo -e "${D}--- 二維碼 (QR Code) ---${N}"
        qrencode -t ANSIUTF8 -k "${link}" 2>/dev/null || qrencode -t ANSI "${link}"
    fi
    echo ""
}

show_node_info() {
    if [[ ! -f "${CONFIG_DIR}/secrets.env" ]]; then warn "未配置"; read -p "返回..." ; show_menu; return; fi
    source "${CONFIG_DIR}/secrets.env"
    
    if [[ -z "${PRISM_ENABLE_SHADOWTLS:-}" ]]; then
        clear; echo -e "${R}[錯誤] 配置文件數據過舊。${N}"; echo "請執行: 4. 配置管理 -> 2. 重置配置"
        read -p "..."; return
    fi

    local ip="${IPV4_ADDR:-${IPV6_ADDR}}"
    if [[ -z "${IPV4_ADDR}" ]]; then ip="[${IPV6_ADDR}]"; fi
    
    clear; print_banner; echo -e " ${P}>>> 節點詳細信息 (Node Details)${N}"

    if [[ "${PRISM_ENABLE_REALITY_VISION}" == "true" ]]; then
        echo -e "${SEP}\n ${G}VLESS Reality Vision${N} (TCP)"
        echo -e " Address (地址) : ${Y}${ip}${N}"
        echo -e " Port (端口)    : ${Y}${PRISM_PORT_REALITY_VISION:-}${N}"
        echo -e " UUID (用戶ID)  : ${C}${PRISM_UUID:-}${N}"
        echo -e " Network (傳輸) : ${C}tcp${N}"
        echo -e " Flow (流控)    : ${C}xtls-rprx-vision${N}"
        echo -e " SNI (偽裝)     : ${C}${PRISM_DEST:-}${N}"
        echo -e " PBK (公鑰)     : ${C}${PRISM_PUBLIC_KEY:-}${N}"
        echo -e " SID (簡碼)     : ${C}${PRISM_SHORT_ID:-}${N}"
        echo -e " Fingerp (指紋) : ${C}chrome${N}"
        local link="vless://${PRISM_UUID:-}@${ip}:${PRISM_PORT_REALITY_VISION:-}?security=reality&encryption=none&pbk=${PRISM_PUBLIC_KEY:-}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=${PRISM_DEST:-}&sid=${PRISM_SHORT_ID:-}#Prism_Vision"
        echo -e " ${D}-----------------------------------------------${N}"
        echo -e " ${Y}${link}${N}"; print_qr_block "${link}"
    fi

    if [[ "${PRISM_ENABLE_REALITY_GRPC}" == "true" ]]; then
        echo -e "${SEP}\n ${G}VLESS Reality gRPC${N}"
        echo -e " Address (地址) : ${Y}${ip}${N}"
        echo -e " Port (端口)    : ${Y}${PRISM_PORT_REALITY_GRPC:-}${N}"
        echo -e " UUID (用戶ID)  : ${C}${PRISM_UUID:-}${N}"
        echo -e " Network (傳輸) : ${C}grpc${N}"
        echo -e " Service (服務) : ${C}grpc${N}"
        echo -e " SNI (偽裝)     : ${C}${PRISM_DEST:-}${N}"
        echo -e " PBK (公鑰)     : ${C}${PRISM_PUBLIC_KEY:-}${N}"
        echo -e " SID (簡碼)     : ${C}${PRISM_SHORT_ID:-}${N}"
        local link="vless://${PRISM_UUID:-}@${ip}:${PRISM_PORT_REALITY_GRPC:-}?security=reality&encryption=none&pbk=${PRISM_PUBLIC_KEY:-}&fp=chrome&type=grpc&serviceName=grpc&sni=${PRISM_DEST:-}&sid=${PRISM_SHORT_ID:-}#Prism_Reality_gRPC"
        echo -e " ${D}-----------------------------------------------${N}"
        echo -e " ${Y}${link}${N}"; print_qr_block "${link}"
    fi

    if [[ "${PRISM_ENABLE_HY2}" == "true" ]]; then
        echo -e "${SEP}\n ${G}Hysteria 2${N} (UDP)"
        echo -e " Address (地址) : ${Y}${ip}${N}"
        local hy2_port_display="${PRISM_PORT_HY2:-}"
        if [[ -n "${PRISM_HY2_PORT_HOPPING:-}" ]]; then
            hy2_port_display="${PRISM_PORT_HY2:-} (Hopping: ${PRISM_HY2_PORT_HOPPING})"
        fi
        echo -e " Port (端口)    : ${Y}${hy2_port_display}${N}"
        echo -e " Password (密碼): ${C}${PRISM_HY2_PASSWORD:-}${N}"
        echo -e " Network (傳輸) : ${C}udp${N}"
        
        local hy2_sni="www.bing.com"
        local hy2_insecure="1"
        local hy2_insecure_label="${R}True${N}"
        if [[ "${PRISM_HY2_CERT_MODE:-}" == "acme" && -n "${PRISM_ACME_DOMAIN:-}" ]]; then
            hy2_sni="${PRISM_ACME_DOMAIN}"
            hy2_insecure="0"
            hy2_insecure_label="${G}False${N}"
        fi
        
        echo -e " SNI (偽裝)     : ${C}${hy2_sni}${N}"
        echo -e " Insecure (驗證): ${hy2_insecure_label}"
        local link="hysteria2://${PRISM_HY2_PASSWORD:-}@${ip}:${PRISM_PORT_HY2:-}?insecure=${hy2_insecure}&sni=${hy2_sni}#Prism_Hy2"
        echo -e " ${D}-----------------------------------------------${N}"
        echo -e " ${Y}${link}${N}"; print_qr_block "${link}"
    fi

    if [[ "${PRISM_ENABLE_TUIC}" == "true" ]]; then
        echo -e "${SEP}\n ${G}TUIC v5${N} (QUIC)"
        echo -e " Address (地址) : ${Y}${ip}${N}"
        local tuic_port_display="${PRISM_PORT_TUIC:-}"
        if [[ -n "${PRISM_TUIC_PORT_HOPPING:-}" ]]; then
            tuic_port_display="${PRISM_PORT_TUIC:-} (Hopping: ${PRISM_TUIC_PORT_HOPPING})"
        fi
        echo -e " Port (端口)    : ${Y}${tuic_port_display}${N}"
        echo -e " UUID (用戶ID)  : ${C}${PRISM_TUIC_UUID:-}${N}"
        echo -e " Password (密碼): ${C}${PRISM_TUIC_PASSWORD:-}${N}"
        echo -e " Network (傳輸) : ${C}udp${N}"
        echo -e " Congest (擁塞) : ${C}bbr${N}"
        
        local tuic_sni="www.bing.com"
        local tuic_insecure="1"
        local tuic_insecure_label="${R}True${N}"
        if [[ "${PRISM_TUIC_CERT_MODE:-}" == "acme" && -n "${PRISM_ACME_DOMAIN:-}" ]]; then
            tuic_sni="${PRISM_ACME_DOMAIN}"
            tuic_insecure="0"
            tuic_insecure_label="${G}False${N}"
        fi

        echo -e " SNI (偽裝)     : ${C}${tuic_sni}${N}"
        echo -e " Insecure (驗證): ${tuic_insecure_label}"
        local link="tuic://${PRISM_TUIC_UUID:-}:${PRISM_TUIC_PASSWORD:-}@${ip}:${PRISM_PORT_TUIC:-}?congestion_control=bbr&udp_relay_mode=native&allow_insecure=${tuic_insecure}&sni=${tuic_sni}#Prism_TUIC"
        echo -e " ${D}-----------------------------------------------${N}"
        echo -e " ${Y}${link}${N}"; print_qr_block "${link}"
    fi

    if [[ "${PRISM_ENABLE_ANYTLS}" == "true" ]]; then
        echo -e "${SEP}\n ${G}AnyTLS${N} (Native TLS)"
        echo -e " Address (地址) : ${Y}${ip}${N}"
        echo -e " Port (端口)    : ${Y}${PRISM_PORT_ANYTLS:-}${N}"
        echo -e " Password (密碼): ${C}${PRISM_ANYTLS_PASSWORD:-}${N}"
        
        local any_sni="www.bing.com"
        local any_insecure="1"
        if [[ "${PRISM_ANYTLS_CERT_MODE:-}" == "acme" && -n "${PRISM_ACME_DOMAIN:-}" ]]; then
            any_sni="${PRISM_ACME_DOMAIN}"
            any_insecure="0"
        fi
        echo -e " SNI (偽裝)     : ${C}${any_sni}${N}"
        
        local link="anytls://${PRISM_ANYTLS_PASSWORD:-}@${ip}:${PRISM_PORT_ANYTLS:-}?sni=${any_sni}&insecure=${any_insecure}&peer=${any_sni}#Prism_AnyTLS"
        echo -e " ${D}-----------------------------------------------${N}"
        echo -e " ${Y}${link}${N}"; print_qr_block "${link}"
    fi

    if [[ "${PRISM_ENABLE_ANYTLS_REALITY}" == "true" ]]; then
        echo -e "${SEP}\n ${G}AnyTLS + Reality${N}"
        echo -e " Address (地址) : ${Y}${ip}${N}"
        echo -e " Port (端口)    : ${Y}${PRISM_PORT_ANYTLS_REALITY:-}${N}"
        echo -e " Password (密碼): ${C}${PRISM_ANYTLS_REALITY_PASSWORD:-}${N}"
        echo -e " SNI (偽裝)     : ${C}${PRISM_DEST:-}${N}"
        echo -e " PBK (公鑰)     : ${C}${PRISM_PUBLIC_KEY:-}${N}"
        echo -e " SID (簡碼)     : ${C}${PRISM_SHORT_ID:-}${N}"
        echo -e " Fingerp (指紋) : ${C}chrome${N}"
        
        local link="anytls://${PRISM_ANYTLS_REALITY_PASSWORD:-}@${ip}:${PRISM_PORT_ANYTLS_REALITY:-}?security=reality&sni=${PRISM_DEST:-}&pbk=${PRISM_PUBLIC_KEY:-}&sid=${PRISM_SHORT_ID:-}&fingerprint=chrome#Prism_AnyTLS_Reality"
        echo -e " ${D}-----------------------------------------------${N}"
        echo -e " ${Y}${link}${N}"; print_qr_block "${link}"
    fi

    if [[ "${PRISM_ENABLE_SHADOWTLS}" == "true" ]]; then
        echo -e "${SEP}\n ${G}ShadowTLS v3${N} (Wrapper)"
        echo -e " Address (地址) : ${Y}${ip}${N}"
        echo -e " Port (端口)    : ${Y}${PRISM_PORT_SHADOWTLS:-}${N}"
        echo -e " Password (密碼): ${C}${PRISM_SHADOWTLS_PASSWORD:-}${N}"
        echo -e " Handshake (握手): ${C}${PRISM_DEST:-www.microsoft.com}${N}"
        echo -e " Version (版本) : ${C}3${N}"
        
        local link="vless://${PRISM_UUID:-}@${ip}:${PRISM_PORT_SHADOWTLS:-}?security=shadowtls&encryption=none&type=tcp&sni=${PRISM_DEST:-www.microsoft.com}&password=${PRISM_SHADOWTLS_PASSWORD:-}&version=3#Prism_ShadowTLS"
        echo -e " ${D}-----------------------------------------------${N}"
        echo -e " ${Y}${link}${N}"; print_qr_block "${link}"
    fi

    read -p "按回車返回菜單..."
    show_menu
}
