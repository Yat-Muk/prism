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

#!/usr/bin/env bash
# modules/config.sh - Updated with Shadowsocks-2022 over ShadowTLS

source "${BASE_DIR}/core/env.sh"
source "${BASE_DIR}/core/log.sh"
source "${BASE_DIR}/core/ui.sh"

PARTS_DIR="${CONFIG_DIR}/parts"
SECRETS_FILE="${CONFIG_DIR}/secrets.env"

init_config_structure() { mkdir -p "${PARTS_DIR}"; }

get_random_port() {
    if command -v shuf &> /dev/null; then shuf -i 10000-60000 -n 1; else echo $((RANDOM % 50000 + 10000)); fi
}

ensure_certificates() {
    local key_file="${CERT_DIR}/self_signed.key"
    local cert_file="${CERT_DIR}/self_signed.crt"
    mkdir -p "${CERT_DIR}"
    if [[ ! -f "${key_file}" ]] || [[ ! -f "${cert_file}" ]]; then
        log_info "生成自簽名證書..."
        openssl req -x509 -newkey rsa:2048 -nodes -sha256 -keyout "${key_file}" -out "${cert_file}" -days 3650 -subj "/CN=www.bing.com" >/dev/null 2>&1
    fi
}

get_cert_paths() {
    local mode="${1:-acme}"
    if [[ "$mode" == "self_signed" ]]; then ensure_certificates; echo "${CERT_DIR}/self_signed.crt|${CERT_DIR}/self_signed.key"; return; fi
    if [[ -n "${PRISM_ACME_DOMAIN:-}" ]]; then
        local acme_crt="${ACME_CERT_DIR}/${PRISM_ACME_DOMAIN}.crt"
        local acme_key="${ACME_CERT_DIR}/${PRISM_ACME_DOMAIN}.key"
        if [[ -f "${acme_crt}" ]] && [[ -f "${acme_key}" ]]; then echo "${acme_crt}|${acme_key}"; return; fi
    fi
    ensure_certificates; echo "${CERT_DIR}/self_signed.crt|${CERT_DIR}/self_signed.key"
}

set_env_default() {
    local key="$1"; local val="$2"
    if [[ -z "${!key}" ]]; then
        if ! grep -q "^export ${key}=" "${SECRETS_FILE}" 2>/dev/null; then echo "export ${key}=\"${val}\"" >> "${SECRETS_FILE}"; fi
        export "${key}=${val}"
    fi
}

manage_secrets() {
    if [[ ! -f "${SECRETS_FILE}" ]]; then touch "${SECRETS_FILE}"; fi
    source "${SECRETS_FILE}"

    if [[ -z "${PRISM_UUID}" ]]; then
        local new_uuid=$(${SINGBOX_BIN} generate uuid)
        set_env_default "PRISM_UUID" "$new_uuid"
    fi

    if [[ -z "${PRISM_TUIC_UUID}" ]]; then
        set_env_default "PRISM_TUIC_UUID" "${PRISM_UUID}"
    fi
    
    if [[ -z "${PRISM_PRIVATE_KEY}" ]]; then
        local keypair=$(${SINGBOX_BIN} generate reality-keypair)
        local pk=$(echo "$keypair" | grep "PrivateKey" | awk '{print $2}')
        local pub=$(echo "$keypair" | grep "PublicKey" | awk '{print $2}')
        set_env_default "PRISM_PRIVATE_KEY" "$pk"
        set_env_default "PRISM_PUBLIC_KEY" "$pub"
        set_env_default "PRISM_SHORT_ID" "$(openssl rand -hex 8)"
        set_env_default "PRISM_DEST" "www.microsoft.com"
        set_env_default "PRISM_DEST_PORT" "443"
    fi

    set_env_default "PRISM_PORT_REALITY_VISION" "$(get_random_port)"
    set_env_default "PRISM_PORT_REALITY_GRPC" "$(get_random_port)"
    set_env_default "PRISM_PORT_HY2" "$(get_random_port)"
    set_env_default "PRISM_PORT_TUIC" "$(get_random_port)"
    set_env_default "PRISM_PORT_ANYTLS" "$(get_random_port)"
    set_env_default "PRISM_PORT_ANYTLS_REALITY" "$(get_random_port)"
    set_env_default "PRISM_PORT_SHADOWTLS" "$(get_random_port)"
    set_env_default "PRISM_PORT_INNER_VLESS" "$(get_random_port)"

    set_env_default "PRISM_HY2_PASSWORD" "$(openssl rand -hex 16)"
    set_env_default "PRISM_TUIC_PASSWORD" "$(openssl rand -hex 8)"
    set_env_default "PRISM_ANYTLS_PASSWORD" "$(openssl rand -hex 16)"
    set_env_default "PRISM_ANYTLS_REALITY_PASSWORD" "$(openssl rand -hex 16)"
    
    if [[ -z "${PRISM_SS_PASSWORD}" ]]; then
        local ss_key=$(openssl rand -base64 16)
        set_env_default "PRISM_SS_PASSWORD" "$ss_key"
    fi
    set_env_default "PRISM_SHADOWTLS_PASSWORD" "$(openssl rand -hex 16)"

    if ! grep -q "PRISM_ENABLE_" "${SECRETS_FILE}"; then
        set_env_default "PRISM_ENABLE_REALITY_VISION" "true"
        set_env_default "PRISM_ENABLE_HY2" "true"
        set_env_default "PRISM_ENABLE_TUIC" "true"
        set_env_default "PRISM_ENABLE_REALITY_GRPC" "false"
        set_env_default "PRISM_ENABLE_ANYTLS" "false"
        set_env_default "PRISM_ENABLE_ANYTLS_REALITY" "false"
        set_env_default "PRISM_ENABLE_SHADOWTLS" "false"
    fi
    set_env_default "PRISM_OUTBOUND_MODE" "prefer_ipv4"
    source "${SECRETS_FILE}"
}

gen_log_config() {
    cat > "${PARTS_DIR}/00_log.json" <<EOF
{ "log": { "level": "info", "output": "${WORK_DIR}/box.log", "timestamp": true } }
EOF
}

gen_dns_config() {
    local extra_dns_rules=""
    if [[ "${PRISM_SNI_ENABLE:-}" == "true" && -n "${PRISM_SNI_IP:-}" ]] && [[ -f "${RULE_DIR}/sni.list" ]]; then
        local sni_domains=$(jq -R . "${RULE_DIR}/sni.list" | jq -s . | sed 's/null//g')
        if [[ "$sni_domains" != "[]" ]]; then
            extra_dns_rules="{ \"domain\": ${sni_domains}, \"rewrite_ip_address\": [\"${PRISM_SNI_IP}\"] },"
        fi
    fi

    cat > "${PARTS_DIR}/01_dns.json" <<EOF
{
  "dns": {
    "servers": [
      { "tag": "dns_google", "server": "8.8.8.8", "type": "udp" },
      { "tag": "dns_local", "type": "local" }
    ],
    "rules": [ 
      ${extra_dns_rules}
      { "rule_set": "geosite-cn", "server": "dns_local" } 
    ],
    "final": "dns_google",
    "strategy": "${PRISM_OUTBOUND_MODE:-prefer_ipv4}"
  }
}
EOF
}

gen_outbounds_config() {
    cat > "${PARTS_DIR}/02_outbounds_base.json" <<EOF
{ "outbounds": [ { "type": "direct", "tag": "direct" }, { "type": "block", "tag": "block" } ] }
EOF

    cat > "${PARTS_DIR}/02_outbounds_ipv6.json" <<EOF
{ "outbounds": [{ "type": "direct", "tag": "ipv6-out", "domain_strategy": "ipv6_only" }] }
EOF

    if [[ "${PRISM_WARP_ENABLE:-}" == "true" ]]; then
        local warp_bind="172.16.0.2"
        local warp_reserved="${PRISM_WARP_RESERVED:-[0,0,0]}"
        [[ -z "$warp_reserved" ]] && warp_reserved="[0,0,0]"
        cat > "${PARTS_DIR}/02_outbounds_warp.json" <<EOF
{
  "outbounds": [{
    "type": "wireguard",
    "tag": "warp-out",
    "server": "162.159.192.1",
    "server_port": 2408,
    "local_address": ["${warp_bind}/32", "${PRISM_WARP_IPV6_ADDR:-}/128"],
    "private_key": "${PRISM_WARP_PRIVATE_KEY:-}",
    "peer_public_key": "${PRISM_WARP_PUBLIC_KEY:-}",
    "reserved": ${warp_reserved},
    "mtu": 1280
  }]
}
EOF
    fi

    if [[ "${PRISM_SOCKS5_OUT_ENABLE:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/02_outbounds_socks5.json" <<EOF
{
  "outbounds": [{
    "type": "socks",
    "tag": "socks5-out",
    "server": "${PRISM_SOCKS5_OUT_IP:-127.0.0.1}",
    "server_port": ${PRISM_SOCKS5_OUT_PORT:-1080},
    "version": "5",
    "username": "${PRISM_SOCKS5_OUT_USER:-}",
    "password": "${PRISM_SOCKS5_OUT_PASS:-}"
  }]
}
EOF
    fi
}

gen_route_config() {
    local warp_rules=""
    local socks5_rules=""
    local ipv6_rules=""
    local final_outbound="direct"

    if [[ "${PRISM_WARP_GLOBAL:-}" == "true" ]]; then final_outbound="warp-out"; fi
    if [[ "${PRISM_SOCKS5_OUT_GLOBAL:-}" == "true" ]]; then final_outbound="socks5-out"; fi
    if [[ "${PRISM_IPV6_GLOBAL:-}" == "true" ]]; then final_outbound="ipv6-out"; fi

    if [[ "${PRISM_WARP_ENABLE:-}" == "true" ]] && [[ -f "${RULE_DIR}/warp.list" ]]; then
        local w_json=$(jq -R . "${RULE_DIR}/warp.list" | jq -s . | sed 's/null//g')
        if [[ "$w_json" != "[]" && -n "$w_json" ]]; then warp_rules="{ \"domain\": ${w_json}, \"outbound\": \"warp-out\" },"; fi
    fi

    if [[ "${PRISM_SOCKS5_OUT_ENABLE:-}" == "true" ]] && [[ -f "${RULE_DIR}/socks5_out.list" ]]; then
        local s_json=$(jq -R . "${RULE_DIR}/socks5_out.list" | jq -s . | sed 's/null//g')
        if [[ "$s_json" != "[]" && -n "$s_json" ]]; then socks5_rules="{ \"domain\": ${s_json}, \"outbound\": \"socks5-out\" },"; fi
    fi
    
    if [[ "${PRISM_SOCKS5_IN_ENABLE:-}" == "true" ]] && [[ -s "${RULE_DIR}/socks5_in.list" ]]; then
         local sin_json=$(jq -R . "${RULE_DIR}/socks5_in.list" | jq -s . | sed 's/null//g')
         if [[ "$sin_json" != "[]" ]]; then
             socks5_rules+="{ \"inbound\": [\"socks5-in\"], \"domain\": ${sin_json}, \"outbound\": \"direct\" }, { \"inbound\": [\"socks5-in\"], \"outbound\": \"block\" },"
         fi
    fi

    if [[ -f "${RULE_DIR}/ipv6.list" ]]; then
        local v6_json=$(jq -R . "${RULE_DIR}/ipv6.list" | jq -s . | sed 's/null//g')
        if [[ "$v6_json" != "[]" && -n "$v6_json" ]]; then ipv6_rules="{ \"domain\": ${v6_json}, \"outbound\": \"ipv6-out\" },"; fi
    fi

    cat > "${PARTS_DIR}/03_route.json" <<EOF
{
  "route": {
    "rule_set": [
      { "tag": "geosite-cn", "type": "remote", "format": "binary", "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs", "download_detour": "direct" },
      { "tag": "geoip-cn", "type": "remote", "format": "binary", "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs", "download_detour": "direct" },
      { "tag": "geosite-ads", "type": "remote", "format": "binary", "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs", "download_detour": "direct" }
    ],
    "rules": [
      { "protocol": "dns", "action": "hijack-dns" },
      ${warp_rules}
      ${socks5_rules}
      ${ipv6_rules}
      { "rule_set": "geosite-ads", "outbound": "block" },
      { "rule_set": ["geoip-cn", "geosite-cn"], "outbound": "direct" }
    ],
    "final": "${final_outbound}",
    "auto_detect_interface": true,
    "default_domain_resolver": { "server": "dns_google" }
  }
}
EOF
}

gen_inbounds_config() {
    rm -f "${PARTS_DIR}/04_inbounds"*.json
    
    if [[ "${PRISM_ENABLE_REALITY_VISION:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/04_inbounds_reality_vision.json" <<EOF
{ "inbounds": [{ "type": "vless", "tag": "vless-reality-vision", "listen": "::", "listen_port": ${PRISM_PORT_REALITY_VISION:-443}, "users": [{ "uuid": "${PRISM_UUID}", "flow": "xtls-rprx-vision" }], "tls": { "enabled": true, "server_name": "${PRISM_DEST}", "reality": { "enabled": true, "handshake": { "server": "${PRISM_DEST}", "server_port": ${PRISM_DEST_PORT:-443} }, "private_key": "${PRISM_PRIVATE_KEY}", "short_id": ["${PRISM_SHORT_ID}"] } } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_REALITY_GRPC:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/04_inbounds_reality_grpc.json" <<EOF
{ "inbounds": [{ "type": "vless", "tag": "vless-reality-grpc", "listen": "::", "listen_port": ${PRISM_PORT_REALITY_GRPC:-8443}, "users": [{ "uuid": "${PRISM_UUID}" }], "transport": { "type": "grpc", "service_name": "grpc" }, "tls": { "enabled": true, "server_name": "${PRISM_DEST}", "reality": { "enabled": true, "handshake": { "server": "${PRISM_DEST}", "server_port": ${PRISM_DEST_PORT:-443} }, "private_key": "${PRISM_PRIVATE_KEY}", "short_id": ["${PRISM_SHORT_ID}"] } } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_HY2:-}" == "true" ]]; then
        local cert_info=$(get_cert_paths "${PRISM_HY2_CERT_MODE:-self_signed}")
        local crt_path=$(echo "$cert_info" | cut -d'|' -f1); local key_path=$(echo "$cert_info" | cut -d'|' -f2)
        cat > "${PARTS_DIR}/04_inbounds_hy2.json" <<EOF
{ "inbounds": [{ "type": "hysteria2", "tag": "hy2-in", "listen": "::", "listen_port": ${PRISM_PORT_HY2:-8888}, "users": [{ "password": "${PRISM_HY2_PASSWORD}" }], "ignore_client_bandwidth": false, "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "${crt_path}", "key_path": "${key_path}" } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_TUIC:-}" == "true" ]]; then
        local cert_info=$(get_cert_paths "${PRISM_TUIC_CERT_MODE:-self_signed}")
        local crt_path=$(echo "$cert_info" | cut -d'|' -f1); local key_path=$(echo "$cert_info" | cut -d'|' -f2)
        cat > "${PARTS_DIR}/04_inbounds_tuic.json" <<EOF
{ "inbounds": [{ "type": "tuic", "tag": "tuic-in", "listen": "::", "listen_port": ${PRISM_PORT_TUIC:-9999}, "users": [{ "uuid": "${PRISM_TUIC_UUID}", "password": "${PRISM_TUIC_PASSWORD}" }], "congestion_control": "bbr", "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "${crt_path}", "key_path": "${key_path}" } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_ANYTLS:-}" == "true" ]]; then
        local cert_info=$(get_cert_paths "${PRISM_ANYTLS_CERT_MODE:-self_signed}")
        local crt_path=$(echo "$cert_info" | cut -d'|' -f1); local key_path=$(echo "$cert_info" | cut -d'|' -f2)
        cat > "${PARTS_DIR}/04_inbounds_anytls.json" <<EOF
{ 
  "inbounds": [{ 
    "type": "anytls", 
    "tag": "anytls-in", 
    "listen": "::", 
    "listen_port": ${PRISM_PORT_ANYTLS:-10443}, 
    "users": [{ "name": "prism", "password": "${PRISM_ANYTLS_PASSWORD}" }], 
    "padding_scheme": [ "stop=8", "0=30-30", "1=100-400", "2=400-500,c,500-1000,c,500-1000,c,500-1000,c,500-1000", "3=9-9,500-1000", "4=500-1000", "5=500-1000", "6=500-1000", "7=500-1000" ],
    "tls": { 
      "enabled": true, 
      "server_name": "${PRISM_ACME_DOMAIN:-www.bing.com}", 
      "certificate_path": "${crt_path}", 
      "key_path": "${key_path}" 
    } 
  }] 
}
EOF
    fi

    if [[ "${PRISM_ENABLE_ANYTLS_REALITY:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/04_inbounds_anytls_reality.json" <<EOF
{ 
  "inbounds": [{ 
    "type": "anytls", 
    "tag": "anytls-reality-in", 
    "listen": "::", 
    "listen_port": ${PRISM_PORT_ANYTLS_REALITY:-20443}, 
    "users": [{ "name": "prism", "password": "${PRISM_ANYTLS_REALITY_PASSWORD}" }], 
    "padding_scheme": [ "stop=8", "0=30-30", "1=100-400", "2=400-500,c,500-1000,c,500-1000,c,500-1000,c,500-1000", "3=9-9,500-1000", "4=500-1000", "5=500-1000", "6=500-1000", "7=500-1000" ],
    "tls": { 
      "enabled": true, 
      "server_name": "${PRISM_DEST}", 
      "reality": { 
        "enabled": true, 
        "handshake": { 
          "server": "${PRISM_DEST}", 
          "server_port": ${PRISM_DEST_PORT:-443} 
        }, 
        "private_key": "${PRISM_PRIVATE_KEY}", 
        "short_id": ["${PRISM_SHORT_ID}"] 
      } 
    } 
  }] 
}
EOF
    fi

    if [[ "${PRISM_ENABLE_SHADOWTLS:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/04_inbounds_shadowtls.json" <<EOF
{ "inbounds": [ { "type": "shadowtls", "tag": "shadowtls-in", "listen": "::", "listen_port": ${PRISM_PORT_SHADOWTLS:-30443}, "version": 3, "users": [{ "password": "${PRISM_SHADOWTLS_PASSWORD}" }], "handshake": { "server": "${PRISM_DEST}", "server_port": 443 }, "detour": "ss-inner" }, { "type": "shadowsocks", "tag": "ss-inner", "listen": "127.0.0.1", "listen_port": ${PRISM_PORT_INNER_VLESS:-40443}, "method": "2022-blake3-aes-128-gcm", "password": "${PRISM_SS_PASSWORD}" } ] }
EOF
    fi
    
    if [[ "${PRISM_SOCKS5_IN_ENABLE:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/04_inbounds_socks5.json" <<EOF
{ "inbounds": [{ "type": "socks", "tag": "socks5-in", "listen": "::", "listen_port": ${PRISM_SOCKS5_IN_PORT:-10808}, "users": [{ "username": "${PRISM_SOCKS5_IN_USER:-prism}", "password": "${PRISM_SOCKS5_IN_PASS:-prism}" }] }] }
EOF
    fi
}

merge_configs() {
    local output_file="${CONFIG_DIR}/config.json"
    if ! command -v jq &> /dev/null; then error "缺少 jq 工具。"; exit 1; fi
    
    local has_error=false
    for json_file in "${PARTS_DIR}"/*.json; do
        if [[ -f "$json_file" ]]; then
            if ! jq . "$json_file" >/dev/null 2>&1; then
                error "配置片段語法錯誤: $(basename "$json_file")"
                has_error=true
            fi
        fi
    done
    if [[ "$has_error" == "true" ]]; then error "配置合併終止"; return 1; fi

    export ENABLE_DEPRECATED_WIREGUARD_OUTBOUND=true
    if jq -s 'reduce .[] as $item ({}; . * $item + 
        (if ($item | has("inbounds")) and (. | has("inbounds")) then {"inbounds": (.inbounds + $item.inbounds)} else {} end) +
        (if ($item | has("outbounds")) and (. | has("outbounds")) then {"outbounds": (.outbounds + $item.outbounds)} else {} end) +
        (if ($item | has("route")) and (. | has("route")) and ($item.route | has("rules")) and (.route | has("rules")) then {"route": {"rules": (.route.rules + $item.route.rules)}} else {} end)
    )' "${PARTS_DIR}"/*.json > "${output_file}"; then
        
        local check_out
        if check_out=$(ENABLE_DEPRECATED_WIREGUARD_OUTBOUND=true ${SINGBOX_BIN} check -c "${output_file}" 2>&1); then 
            success "配置生成並驗證通過"
        else 
            error "Sing-box 核心校驗失敗"
            echo -e "${R}${check_out}${N}"
            return 1
        fi
    else 
        error "配置文件合併失敗"
        exit 1
    fi
}

build_config() {
    init_config_structure
    manage_secrets
    gen_log_config
    gen_dns_config
    gen_outbounds_config
    gen_route_config
    gen_inbounds_config
    merge_configs
}
