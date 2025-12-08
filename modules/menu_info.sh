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
    local key="$1"; local val="$2"; local target_width=22
    local total_bytes=$(echo -n "$key" | wc -c)
    local non_ascii_bytes=$(echo -n "$key" | sed 's/[\x20-\x7e]//g' | wc -c)
    local visual_width=$((total_bytes - (non_ascii_bytes / 3)))
    local pad_len=$((target_width - visual_width))
    if [[ $pad_len -lt 1 ]]; then pad_len=1; fi
    local padding=$(printf "%${pad_len}s" "")
    echo -e " ${C}${key}${N}${padding} : ${W}${val}${N}"
}

get_node_ip() {
    local ip="${IPV4_ADDR:-${IPV6_ADDR}}"
    echo "$ip"
}

check_sni_connectivity() {
    local sni="${PRISM_DEST:-www.microsoft.com}"
    echo -ne " ${D}正在檢測 SNI 連通性 ($sni)...${N}"
    
    local status_code=$(curl -I -m 3 -o /dev/null -s -w "%{http_code}" "https://$sni")
    
    if [[ "$status_code" =~ ^(200|301|302|307)$ ]]; then
        echo -e "\r                                        \r"
        return 0
    else
        echo -e "\r ${R}[警告] SNI 域名無法連接 (Code: $status_code)${N}"
        echo -e " ${Y}這會導致 Reality 協議握手失敗！請在設置中更換 SNI。${N}"
        echo -e "${SEP}"
        return 1
    fi
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

    check_sni_connectivity

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
        
        local sni="www.bing.com"; local insecure_val="1"; local cert_status="${R}自簽名 (Self-signed)${N}"; local insecure_display="${Y}true${N}"
        if [[ "${PRISM_HY2_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni="${PRISM_ACME_DOMAIN}"; insecure_val="0"; cert_status="${G}ACME (Valid)${N}"; insecure_display="${G}false${N}"; fi
        
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
        
        local sni="www.bing.com"; local insecure_val="1"; local cert_status="${R}自簽名 (Self-signed)${N}"; local insecure_display="${Y}true${N}"
        if [[ "${PRISM_TUIC_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni="${PRISM_ACME_DOMAIN}"; insecure_val="0"; cert_status="${G}ACME (Valid)${N}"; insecure_display="${G}false${N}"; fi
        
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
        p_kv "ShadowTLS Pwd (偽裝)" "${W}${PRISM_SHADOWTLS_PASSWORD}${N}"
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
    local proto=$1; local ip=$(get_node_ip)
    
    if ! command -v jq &>/dev/null; then echo "{}"; return; fi

    local sni_hy2="www.bing.com"; local insecure_hy2=true; if [[ "${PRISM_HY2_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni_hy2="${PRISM_ACME_DOMAIN}"; insecure_hy2=false; fi
    local sni_tuic="www.bing.com"; local insecure_tuic=true; if [[ "${PRISM_TUIC_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni_tuic="${PRISM_ACME_DOMAIN}"; insecure_tuic=false; fi
    local sni_any="www.bing.com"; local insecure_any=true; if [[ "${PRISM_ANYTLS_CERT_MODE}" == "acme" && -n "${PRISM_ACME_DOMAIN}" ]]; then sni_any="${PRISM_ACME_DOMAIN}"; insecure_any=false; fi

    case "$proto" in
        "vision") 
            jq -n --arg ip "$ip" --arg port "$PRISM_PORT_REALITY_VISION" --arg uuid "$PRISM_UUID" --arg sni "$PRISM_DEST" --arg pbk "$PRISM_PUBLIC_KEY" --arg sid "$PRISM_SHORT_ID" \
                '{type: "vless", tag: "Vision", server: $ip, server_port: ($port|tonumber), uuid: $uuid, flow: "xtls-rprx-vision", tls: {enabled: true, server_name: $sni, utls: {enabled: true, fingerprint: "chrome"}, reality: {enabled: true, public_key: $pbk, short_id: $sid}}, packet_encoding: "xudp"}' ;;
        "grpc")
            jq -n --arg ip "$ip" --arg port "$PRISM_PORT_REALITY_GRPC" --arg uuid "$PRISM_UUID" --arg sni "$PRISM_DEST" --arg pbk "$PRISM_PUBLIC_KEY" --arg sid "$PRISM_SHORT_ID" \
                '{type: "vless", tag: "gRPC", server: $ip, server_port: ($port|tonumber), uuid: $uuid, transport: {type: "grpc", service_name: "grpc"}, tls: {enabled: true, server_name: $sni, utls: {enabled: true, fingerprint: "chrome"}, reality: {enabled: true, public_key: $pbk, short_id: $sid}}}' ;;
        "hy2") 
            local port_val=$PRISM_PORT_HY2
            if [[ -n "${PRISM_HY2_PORT_HOPPING}" ]]; then port_val="${PRISM_HY2_PORT_HOPPING//-/:}"; fi
            jq -n --arg ip "$ip" --arg port "$port_val" --arg pwd "$PRISM_HY2_PASSWORD" --arg sni "$sni_hy2" --argjson ins "$insecure_hy2" \
                '{type: "hysteria2", tag: "Hy2", server: $ip, server_port: (if ($port | test("^[0-9]+$")) then ($port|tonumber) else $port end), password: $pwd, tls: {enabled: true, server_name: $sni, insecure: $ins, alpn: ["h3"]}}' ;;
        "tuic") 
            jq -n --arg ip "$ip" --arg port "$PRISM_PORT_TUIC" --arg uuid "$PRISM_TUIC_UUID" --arg pwd "$PRISM_TUIC_PASSWORD" --arg sni "$sni_tuic" --argjson ins "$insecure_tuic" \
                '{type: "tuic", tag: "TUIC", server: $ip, server_port: ($port|tonumber), uuid: $uuid, password: $pwd, congestion_control: "bbr", udp_relay_mode: "native", tls: {enabled: true, server_name: $sni, insecure: $ins, alpn: ["h3"]}}' ;;
        "anytls") 
            jq -n --arg ip "$ip" --arg port "$PRISM_PORT_ANYTLS" --arg pwd "$PRISM_ANYTLS_PASSWORD" --arg sni "$sni_any" --argjson ins "$insecure_any" \
                '{type: "anytls", tag: "AnyTLS", server: $ip, server_port: ($port|tonumber), name: "prism", password: $pwd, tls: {enabled: true, server_name: $sni, insecure: $ins}}' ;;
        "anyreality") 
            jq -n --arg ip "$ip" --arg port "$PRISM_PORT_ANYTLS_REALITY" --arg pwd "$PRISM_ANYTLS_REALITY_PASSWORD" --arg sni "$PRISM_DEST" --arg pbk "$PRISM_PUBLIC_KEY" --arg sid "$PRISM_SHORT_ID" \
                '{type: "anytls", tag: "AnyReality", server: $ip, server_port: ($port|tonumber), name: "prism", password: $pwd, tls: {enabled: true, server_name: $sni, reality: {enabled: true, public_key: $pbk, short_id: $sid}, utls: {enabled: true, fingerprint: "chrome"}}}' ;;
        "shadowtls")
            jq -n --arg ip "$ip" --arg port "$PRISM_PORT_SHADOWTLS" --arg pwd "$PRISM_SHADOWTLS_PASSWORD" --arg sni "$PRISM_DEST" \
                '{type: "shadowtls", tag: "ShadowTLS-Out", server: $ip, server_port: ($port|tonumber), version: 3, password: $pwd, tls: {enabled: true, server_name: $sni, utls: {enabled: true, fingerprint: "chrome"}}}' ;;
        *) echo "{}" ;;
    esac
}

display_client_json() {
    clear; print_banner
    echo -e " ${P}>>> 生成客戶端配置 (Client JSON)${N}"
    echo -e "${SEP}"
    echo -e " 請選擇你的 Sing-box 核心版本："
    echo -e "  ${P}1.${N} ${W}v1.11 及以下${N} ${D}(舊版兼容格式)${N}"
    echo -e "  ${P}2.${N} ${G}v1.12 及以上${N} ${D}(新版標準格式)${N}"
    echo -e "${SEP}"
    echo -e "  ${P}0.${N} 返回"
    echo -e "${SEP}"
    echo -ne " 請輸入選項: "; read -r ver_choice
    
    if [[ "$ver_choice" == "0" ]]; then show_menu; return; fi
    if [[ "$ver_choice" != "1" && "$ver_choice" != "2" ]]; then error "無效選擇"; sleep 1; display_client_json; return; fi

    clear; print_banner
    echo -e " ${P}>>> 正在生成配置 (jq mode)...${N}"; echo -e "${SEP}"

    JSON_OUTBOUNDS=(); PROXY_TAGS=()
    if [[ "${PRISM_ENABLE_REALITY_VISION}" == "true" ]]; then JSON_OUTBOUNDS+=("$(generate_json_outbound_object "vision")"); PROXY_TAGS+=("Vision"); fi
    if [[ "${PRISM_ENABLE_REALITY_GRPC}" == "true" ]]; then JSON_OUTBOUNDS+=("$(generate_json_outbound_object "grpc")"); PROXY_TAGS+=("gRPC"); fi
    if [[ "${PRISM_ENABLE_HY2}" == "true" ]]; then JSON_OUTBOUNDS+=("$(generate_json_outbound_object "hy2")"); PROXY_TAGS+=("Hy2"); fi
    if [[ "${PRISM_ENABLE_TUIC}" == "true" ]]; then JSON_OUTBOUNDS+=("$(generate_json_outbound_object "tuic")"); PROXY_TAGS+=("TUIC"); fi
    if [[ "${PRISM_ENABLE_ANYTLS}" == "true" ]]; then JSON_OUTBOUNDS+=("$(generate_json_outbound_object "anytls")"); PROXY_TAGS+=("AnyTLS"); fi
    if [[ "${PRISM_ENABLE_ANYTLS_REALITY}" == "true" ]]; then JSON_OUTBOUNDS+=("$(generate_json_outbound_object "anyreality")"); PROXY_TAGS+=("AnyReality"); fi
    
    if [[ "${PRISM_ENABLE_SHADOWTLS}" == "true" ]]; then
        JSON_OUTBOUNDS+=("$(generate_json_outbound_object "shadowtls")")
        local ss_json=$(jq -n --arg pwd "$PRISM_SS_PASSWORD" '{type: "shadowsocks", tag: "ShadowTLS", detour: "ShadowTLS-Out", method: "2022-blake3-aes-128-gcm", password: $pwd}')
        JSON_OUTBOUNDS+=("$ss_json")
        PROXY_TAGS+=("ShadowTLS")
    fi

    if [[ "$ver_choice" == "1" ]]; then
        local legacy_outbounds=(); local legacy_tags=()
        for i in "${!JSON_OUTBOUNDS[@]}"; do
            if [[ "${JSON_OUTBOUNDS[$i]}" != *"\"type\": \"anytls\""* ]]; then
                legacy_outbounds+=("${JSON_OUTBOUNDS[$i]}")
                legacy_tags+=("${PROXY_TAGS[$i]}")
            fi
        done
        JSON_OUTBOUNDS=("${legacy_outbounds[@]}")
        PROXY_TAGS=("${legacy_tags[@]}")
        if [[ ${#JSON_OUTBOUNDS[@]} -eq 0 ]]; then warn "無兼容 v1.11 的節點"; read -p "..."; show_menu; return; fi
    fi

    if [[ ${#PROXY_TAGS[@]} -eq 0 ]]; then warn "無可用節點"; read -p "..."; show_menu; return; fi

    local temp_file="${WORK_DIR}/temp_client.json"
    local tags_json=$(printf '%s\n' "${PROXY_TAGS[@]}" | jq -R . | jq -s .)
    local outbounds_json=$(printf '%s\n' "${JSON_OUTBOUNDS[@]}" | jq -s .)
    local selector_tag="🚀 節點選擇"
    local auto_tag="⚡ 自動選擇"

    if [[ "$ver_choice" == "1" ]]; then
        jq -n \
           --arg selector "$selector_tag" \
           --arg auto "$auto_tag" \
           --argjson tags "$tags_json" \
           --argjson nodes "$outbounds_json" \
           '{
             log: {level: "info", disabled: false, timestamp: true},
             experimental: {cache_file: {enabled: true, path: "cache.db", store_fakeip: true}},
             dns: {
               servers: [
                 {tag: "dns-remote", address: "tls://8.8.8.8", detour: $selector},
                 {tag: "dns-local", address: "223.5.5.5", detour: "direct"},
                 {tag: "dns-block", address: "rcode://success"}
               ],
               rules: [
                 {outbound: "any", server: "dns-local"},
                 {rule_set: "geosite-cn", server: "dns-local"},
                 {rule_set: "geosite-geolocation-!cn", server: "dns-remote"}
               ],
               strategy: "ipv4_only", independent_cache: true, final: "dns-remote"
             },
             inbounds: [
               {type: "tun", tag: "tun-in", interface_name: "tun0", inet4_address: "172.19.0.1/30", auto_route: true, strict_route: true, stack: "gvisor", sniff: true},
               {type: "mixed", tag: "mixed-in", listen: "127.0.0.1", listen_port: 2080, sniff: true}
             ],
             route: {
               final: $selector, auto_detect_interface: true,
               rule_set: [
                 {tag: "geosite-geolocation-!cn", type: "remote", format: "binary", url: "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs", download_detour: $selector},
                 {tag: "geosite-cn", type: "remote", format: "binary", url: "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs", download_detour: $selector},
                 {tag: "geosite-category-ads-all", type: "remote", format: "binary", url: "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs", download_detour: $selector},
                 {tag: "geoip-cn", type: "remote", format: "binary", url: "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs", download_detour: $selector}
               ],
               rules: [
                 {protocol: "dns", outbound: "dns-out"},
                 {rule_set: "geosite-category-ads-all", outbound: "block"},
                 {rule_set: ["geoip-cn", "geosite-cn"], outbound: "direct"},
                 {rule_set: "geosite-geolocation-!cn", outbound: $selector}
               ]
             },
             outbounds: (
               [{type: "selector", tag: $selector, outbounds: ([$auto] + $tags + ["direct"])},
                {type: "urltest", tag: $auto, outbounds: $tags, url: "http://www.gstatic.com/generate_204", interval: "3m"}] 
               + $nodes 
               + [{type: "direct", tag: "direct"}, {type: "block", tag: "block"}, {type: "dns", tag: "dns-out"}]
             )
           }' > "${temp_file}"

    else
        jq -n \
           --arg selector "$selector_tag" \
           --arg auto "$auto_tag" \
           --argjson tags "$tags_json" \
           --argjson nodes "$outbounds_json" \
           '{
             log: {level: "info", timestamp: true},
             experimental: {cache_file: {enabled: true, path: "cache.db", store_fakeip: true}},
             dns: {
               servers: [
                 {tag: "dns-local", type: "https", server: "223.5.5.5"},
                 {tag: "dns-remote", type: "https", server: "8.8.8.8", detour: $selector}
               ],
               rules: [
                 {rule_set: ["geosite-category-ads-all"], action: "reject"},
                 {rule_set: "geosite-cn", server: "dns-local"},
                 {rule_set: "geosite-geolocation-!cn", server: "dns-remote"}
               ],
               strategy: "ipv4_only", independent_cache: true, final: "dns-remote"
             },
             inbounds: [
               {
                 type: "tun", tag: "tun-in", interface_name: "tun0", address: "172.19.0.1/30", mtu: 9000,
                 auto_route: true, strict_route: true, stack: "system",
                 route_exclude_address: ["192.168.0.0/16", "10.0.0.0/8", "172.16.0.0/12", "fc00::/7"]
               },
               {type: "mixed", tag: "mixed-in", listen: "127.0.0.1", listen_port: 2080}
             ],
             route: {
               final: $selector, auto_detect_interface: true, default_domain_resolver: "dns-remote",
               rule_set: [
                 {tag: "geosite-geolocation-!cn", type: "remote", format: "binary", url: "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs", download_detour: $selector},
                 {tag: "geosite-cn", type: "remote", format: "binary", url: "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs", download_detour: $selector},
                 {tag: "geosite-category-ads-all", type: "remote", format: "binary", url: "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs", download_detour: $selector},
                 {tag: "geoip-cn", type: "remote", format: "binary", url: "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs", download_detour: $selector}
               ],
               rules: [
                 {action: "sniff"},
                 {protocol: "dns", action: "hijack-dns"},
                 {ip_is_private: true, outbound: "direct"},
                 {rule_set: ["geosite-category-ads-all"], action: "reject"},
                 {rule_set: ["geoip-cn", "geosite-cn"], outbound: "direct"},
                 {rule_set: "geosite-geolocation-!cn", outbound: $selector}
               ]
             },
             outbounds: (
               [{tag: $selector, type: "selector", outbounds: ([$auto] + $tags + ["direct"])},
                {tag: $auto, type: "urltest", outbounds: $tags, url: "http://www.gstatic.com/generate_204", interval: "3m"}]
               + $nodes
               + [{tag: "direct", type: "direct"}]
             )
           }' > "${temp_file}"
    fi

    if [[ -s "${temp_file}" ]]; then
        cat "${temp_file}" | jq .
    else
        error "JSON 生成失敗"
    fi
    rm -f "${temp_file}"
    echo -e "${SEP}"; read -p " 按回車返回主菜單..."
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