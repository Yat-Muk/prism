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
    if [[ ! -f "${key_file}" ]] || [[ ! -f "${cert_file}" ]]; then
        log_info "生成自簽名證書..."
        openssl req -x509 -newkey rsa:2048 -nodes -sha256 -keyout "${key_file}" -out "${cert_file}" -days 3650 -subj "/CN=www.bing.com" >/dev/null 2>&1
        success "自簽名證書生成完畢"
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

manage_secrets() {
    if [[ -f "${SECRETS_FILE}" ]]; then source "${SECRETS_FILE}"; fi

    : "${PRISM_UUID:=}" "${PRISM_PRIVATE_KEY:=}" "${PRISM_PUBLIC_KEY:=}" "${PRISM_SHORT_ID:=}" "${PRISM_DEST:=}" "${PRISM_DEST_PORT:=}"
    : "${PRISM_ENABLE_REALITY_VISION:=}" "${PRISM_PORT_REALITY_VISION:=}"
    : "${PRISM_ENABLE_REALITY_GRPC:=}" "${PRISM_PORT_REALITY_GRPC:=}"
    : "${PRISM_ENABLE_HY2:=}" "${PRISM_PORT_HY2:=}" "${PRISM_HY2_PASSWORD:=}" "${PRISM_HY2_CERT_MODE:=}"
    : "${PRISM_ENABLE_TUIC:=}" "${PRISM_PORT_TUIC:=}" "${PRISM_TUIC_UUID:=}" "${PRISM_TUIC_PASSWORD:=}" "${PRISM_TUIC_CERT_MODE:=}"
    : "${PRISM_ENABLE_ANYTLS:=}" "${PRISM_PORT_ANYTLS:=}" "${PRISM_ANYTLS_PASSWORD:=}" "${PRISM_ANYTLS_CERT_MODE:=}"
    : "${PRISM_ENABLE_ANYTLS_REALITY:=}" "${PRISM_PORT_ANYTLS_REALITY:=}" "${PRISM_ANYTLS_REALITY_PASSWORD:=}"
    : "${PRISM_ENABLE_SHADOWTLS:=}" "${PRISM_PORT_SHADOWTLS:=}" "${PRISM_SHADOWTLS_PASSWORD:=}" "${PRISM_PORT_INNER_VLESS:=}"
    : "${PRISM_OUTBOUND_MODE:=}"

    : "${PRISM_WARP_ENABLE:=false}" "${PRISM_WARP_PRIVATE_KEY:=}" "${PRISM_WARP_PUBLIC_KEY:=}" 
    : "${PRISM_WARP_IPV6_ADDR:=}" "${PRISM_WARP_RESERVED:=[0,0,0]}" "${PRISM_WARP_TYPE:=IPv4}" "${PRISM_WARP_GLOBAL:=false}"
    
    : "${PRISM_SOCKS5_OUT_ENABLE:=false}" "${PRISM_SOCKS5_OUT_IP:=}" "${PRISM_SOCKS5_OUT_PORT:=}" 
    : "${PRISM_SOCKS5_OUT_USER:=}" "${PRISM_SOCKS5_OUT_PASS:=}" "${PRISM_SOCKS5_OUT_GLOBAL:=false}"
    
    : "${PRISM_SOCKS5_IN_ENABLE:=false}" "${PRISM_SOCKS5_IN_PORT:=}" "${PRISM_SOCKS5_IN_USER:=}" "${PRISM_SOCKS5_IN_PASS:=}"
    
    : "${PRISM_DNS_ENABLE:=false}" "${PRISM_DNS_IP:=}"
    : "${PRISM_SNI_ENABLE:=false}" "${PRISM_SNI_IP:=}"
    : "${PRISM_IPV6_GLOBAL:=false}"
    : "${PRISM_ACME_DOMAIN:=}"

    local save_needed=false

    if [[ -z "${PRISM_UUID}" ]]; then PRISM_UUID=$(${SINGBOX_BIN} generate uuid); save_needed=true; fi
    if [[ -z "${PRISM_PRIVATE_KEY}" ]]; then
        local keypair=$(${SINGBOX_BIN} generate reality-keypair)
        PRISM_PRIVATE_KEY=$(echo "$keypair" | grep "PrivateKey" | awk '{print $2}')
        PRISM_PUBLIC_KEY=$(echo "$keypair" | grep "PublicKey" | awk '{print $2}')
        PRISM_SHORT_ID=$(openssl rand -hex 8); PRISM_DEST="www.microsoft.com"; PRISM_DEST_PORT=443; save_needed=true
    fi

    if [[ -z "${PRISM_PORT_REALITY_VISION}" ]]; then PRISM_PORT_REALITY_VISION=$(get_random_port); export PRISM_PORT_REALITY_VISION; save_needed=true; fi
    if [[ -z "${PRISM_PORT_REALITY_GRPC}" ]]; then PRISM_PORT_REALITY_GRPC=$(get_random_port); export PRISM_PORT_REALITY_GRPC; save_needed=true; fi
    if [[ -z "${PRISM_PORT_HY2}" ]]; then PRISM_PORT_HY2=$(get_random_port); export PRISM_PORT_HY2; save_needed=true; fi
    if [[ -z "${PRISM_PORT_TUIC}" ]]; then PRISM_PORT_TUIC=$(get_random_port); export PRISM_PORT_TUIC; save_needed=true; fi
    if [[ -z "${PRISM_PORT_ANYTLS}" ]]; then PRISM_PORT_ANYTLS=$(get_random_port); export PRISM_PORT_ANYTLS; save_needed=true; fi
    if [[ -z "${PRISM_PORT_ANYTLS_REALITY}" ]]; then PRISM_PORT_ANYTLS_REALITY=$(get_random_port); export PRISM_PORT_ANYTLS_REALITY; save_needed=true; fi
    if [[ -z "${PRISM_PORT_SHADOWTLS}" ]]; then PRISM_PORT_SHADOWTLS=$(get_random_port); export PRISM_PORT_SHADOWTLS; save_needed=true; fi
    if [[ -z "${PRISM_PORT_INNER_VLESS}" ]]; then PRISM_PORT_INNER_VLESS=$(get_random_port); export PRISM_PORT_INNER_VLESS; save_needed=true; fi

    if [[ -z "${PRISM_HY2_PASSWORD}" ]]; then PRISM_HY2_PASSWORD=$(openssl rand -hex 16); save_needed=true; fi
    if [[ -z "${PRISM_TUIC_UUID}" ]]; then PRISM_TUIC_UUID=$(${SINGBOX_BIN} generate uuid); save_needed=true; fi
    if [[ -z "${PRISM_TUIC_PASSWORD}" ]]; then PRISM_TUIC_PASSWORD=$(openssl rand -hex 8); save_needed=true; fi
    if [[ -z "${PRISM_ANYTLS_PASSWORD}" ]]; then PRISM_ANYTLS_PASSWORD=$(openssl rand -hex 16); save_needed=true; fi
    if [[ -z "${PRISM_ANYTLS_REALITY_PASSWORD}" ]]; then PRISM_ANYTLS_REALITY_PASSWORD=$(openssl rand -hex 16); save_needed=true; fi
    if [[ -z "${PRISM_SHADOWTLS_PASSWORD}" ]]; then PRISM_SHADOWTLS_PASSWORD=$(openssl rand -hex 16); save_needed=true; fi
    
    if [[ -z "${PRISM_HY2_CERT_MODE}" ]]; then PRISM_HY2_CERT_MODE="acme"; save_needed=true; fi
    if [[ -z "${PRISM_TUIC_CERT_MODE}" ]]; then PRISM_TUIC_CERT_MODE="acme"; save_needed=true; fi
    if [[ -z "${PRISM_ANYTLS_CERT_MODE}" ]]; then PRISM_ANYTLS_CERT_MODE="acme"; save_needed=true; fi

    if [[ -z "${PRISM_OUTBOUND_MODE}" ]]; then PRISM_OUTBOUND_MODE="prefer_ipv4"; save_needed=true; fi

    if [[ "$save_needed" == "true" ]]; then
        cat > "${SECRETS_FILE}" <<EOF
export PRISM_UUID="${PRISM_UUID:-}"
export PRISM_PRIVATE_KEY="${PRISM_PRIVATE_KEY:-}"
export PRISM_PUBLIC_KEY="${PRISM_PUBLIC_KEY:-}"
export PRISM_SHORT_ID="${PRISM_SHORT_ID:-}"
export PRISM_DEST="${PRISM_DEST:-}"
export PRISM_DEST_PORT="${PRISM_DEST_PORT:-}"
export PRISM_ENABLE_REALITY_VISION="${PRISM_ENABLE_REALITY_VISION:-}"
export PRISM_PORT_REALITY_VISION="${PRISM_PORT_REALITY_VISION:-}"
export PRISM_ENABLE_REALITY_GRPC="${PRISM_ENABLE_REALITY_GRPC:-}"
export PRISM_PORT_REALITY_GRPC="${PRISM_PORT_REALITY_GRPC:-}"
export PRISM_ENABLE_HY2="${PRISM_ENABLE_HY2:-}"
export PRISM_PORT_HY2="${PRISM_PORT_HY2:-}"
export PRISM_HY2_PASSWORD="${PRISM_HY2_PASSWORD:-}"
export PRISM_HY2_CERT_MODE="${PRISM_HY2_CERT_MODE:-}"
export PRISM_ENABLE_TUIC="${PRISM_ENABLE_TUIC:-}"
export PRISM_PORT_TUIC="${PRISM_PORT_TUIC:-}"
export PRISM_TUIC_UUID="${PRISM_TUIC_UUID:-}"
export PRISM_TUIC_PASSWORD="${PRISM_TUIC_PASSWORD:-}"
export PRISM_TUIC_CERT_MODE="${PRISM_TUIC_CERT_MODE:-}"
export PRISM_ENABLE_ANYTLS="${PRISM_ENABLE_ANYTLS:-}"
export PRISM_PORT_ANYTLS="${PRISM_PORT_ANYTLS:-}"
export PRISM_ANYTLS_PASSWORD="${PRISM_ANYTLS_PASSWORD:-}"
export PRISM_ANYTLS_CERT_MODE="${PRISM_ANYTLS_CERT_MODE:-}"
export PRISM_ENABLE_ANYTLS_REALITY="${PRISM_ENABLE_ANYTLS_REALITY:-}"
export PRISM_PORT_ANYTLS_REALITY="${PRISM_PORT_ANYTLS_REALITY:-}"
export PRISM_ANYTLS_REALITY_PASSWORD="${PRISM_ANYTLS_REALITY_PASSWORD:-}"
export PRISM_ENABLE_SHADOWTLS="${PRISM_ENABLE_SHADOWTLS:-}"
export PRISM_PORT_SHADOWTLS="${PRISM_PORT_SHADOWTLS:-}"
export PRISM_SHADOWTLS_PASSWORD="${PRISM_SHADOWTLS_PASSWORD:-}"
export PRISM_PORT_INNER_VLESS="${PRISM_PORT_INNER_VLESS:-}"
export PRISM_OUTBOUND_MODE="${PRISM_OUTBOUND_MODE:-}"
EOF
        if [[ -n "${PRISM_WARP_PRIVATE_KEY:-}" ]]; then
            cat >> "${SECRETS_FILE}" <<WEOF
export PRISM_WARP_ENABLE="${PRISM_WARP_ENABLE:-false}"
export PRISM_WARP_PRIVATE_KEY="${PRISM_WARP_PRIVATE_KEY:-}"
export PRISM_WARP_PUBLIC_KEY="${PRISM_WARP_PUBLIC_KEY:-}"
export PRISM_WARP_IPV6_ADDR="${PRISM_WARP_IPV6_ADDR:-}"
export PRISM_WARP_RESERVED="${PRISM_WARP_RESERVED:-[0,0,0]}"
export PRISM_WARP_TYPE="${PRISM_WARP_TYPE:-IPv4}"
export PRISM_WARP_GLOBAL="${PRISM_WARP_GLOBAL:-false}"
WEOF
        fi
        if [[ -n "${PRISM_SOCKS5_OUT_IP:-}" ]]; then
            cat >> "${SECRETS_FILE}" <<SEOF
export PRISM_SOCKS5_OUT_ENABLE="${PRISM_SOCKS5_OUT_ENABLE:-false}"
export PRISM_SOCKS5_OUT_IP="${PRISM_SOCKS5_OUT_IP:-}"
export PRISM_SOCKS5_OUT_PORT="${PRISM_SOCKS5_OUT_PORT:-}"
export PRISM_SOCKS5_OUT_USER="${PRISM_SOCKS5_OUT_USER:-}"
export PRISM_SOCKS5_OUT_PASS="${PRISM_SOCKS5_OUT_PASS:-}"
export PRISM_SOCKS5_OUT_GLOBAL="${PRISM_SOCKS5_OUT_GLOBAL:-false}"
SEOF
        fi
        if [[ -n "${PRISM_SOCKS5_IN_PORT:-}" ]]; then
            cat >> "${SECRETS_FILE}" <<SIN
export PRISM_SOCKS5_IN_ENABLE="${PRISM_SOCKS5_IN_ENABLE:-false}"
export PRISM_SOCKS5_IN_PORT="${PRISM_SOCKS5_IN_PORT:-}"
export PRISM_SOCKS5_IN_USER="${PRISM_SOCKS5_IN_USER:-}"
export PRISM_SOCKS5_IN_PASS="${PRISM_SOCKS5_IN_PASS:-}"
SIN
        fi
        if [[ -n "${PRISM_DNS_IP:-}" ]]; then
            cat >> "${SECRETS_FILE}" <<DNS
export PRISM_DNS_ENABLE="${PRISM_DNS_ENABLE:-false}"
export PRISM_DNS_IP="${PRISM_DNS_IP:-}"
DNS
        fi
        if [[ -n "${PRISM_SNI_IP:-}" ]]; then
            cat >> "${SECRETS_FILE}" <<SNI
export PRISM_SNI_ENABLE="${PRISM_SNI_ENABLE:-false}"
export PRISM_SNI_IP="${PRISM_SNI_IP:-}"
SNI
        fi
        if [[ "${PRISM_IPV6_GLOBAL:-}" == "true" ]]; then
             echo "export PRISM_IPV6_GLOBAL=\"true\"" >> "${SECRETS_FILE}"
        fi
        if [[ -n "${PRISM_ACME_DOMAIN:-}" ]]; then
             echo "export PRISM_ACME_DOMAIN=\"${PRISM_ACME_DOMAIN}\"" >> "${SECRETS_FILE}"
        fi
    fi
}

gen_log_config() {
    cat > "${PARTS_DIR}/00_log.json" <<EOF
{ "log": { "level": "info", "output": "${WORK_DIR}/box.log", "timestamp": true } }
EOF
}

gen_dns_config() {
    cat > "${PARTS_DIR}/01_dns.json" <<EOF
{
  "dns": {
    "servers": [
      { "tag": "dns_google", "server": "8.8.8.8", "type": "udp" },
      { "tag": "dns_local", "type": "local" }
    ],
    "rules": [ { "rule_set": "geosite-cn", "server": "dns_local" } ],
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

    if [[ "${PRISM_WARP_ENABLE:-}" == "true" ]]; then
        local warp_bind="172.16.0.2"
        if [[ "${PRISM_WARP_TYPE:-}" == "IPv6" ]]; then warp_bind="${PRISM_WARP_IPV6_ADDR:-}"; fi
        local warp_reserved="${PRISM_WARP_RESERVED:-[0,0,0]}"
        if [[ -z "$warp_reserved" ]]; then warp_reserved="[0,0,0]"; fi
        
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
        local s5_port="${PRISM_SOCKS5_OUT_PORT:-1080}"
        cat > "${PARTS_DIR}/02_outbounds_socks5.json" <<EOF
{
  "outbounds": [{
    "type": "socks",
    "tag": "socks5-out",
    "server": "${PRISM_SOCKS5_OUT_IP:-127.0.0.1}",
    "server_port": ${s5_port},
    "version": "5",
    "username": "${PRISM_SOCKS5_OUT_USER:-}",
    "password": "${PRISM_SOCKS5_OUT_PASS:-}"
  }]
}
EOF
    fi

    cat > "${PARTS_DIR}/02_outbounds_ipv6.json" <<EOF
{ "outbounds": [{ "type": "direct", "tag": "ipv6-out", "domain_strategy": "ipv6_only" }] }
EOF
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
        local warp_domains=(); mapfile -t warp_domains < "${RULE_DIR}/warp.list"
        local w_json=$(printf '%s\n' "${warp_domains[@]}" | jq -R . | jq -s . | sed 's/null//g')
        if [[ "$w_json" != "[]" && -n "$w_json" ]]; then warp_rules="{ \"domain\": ${w_json}, \"outbound\": \"warp-out\" },"; fi
    fi

    if [[ "${PRISM_SOCKS5_OUT_ENABLE:-}" == "true" ]] && [[ -f "${RULE_DIR}/socks5_out.list" ]]; then
        local s5_domains=(); mapfile -t s5_domains < "${RULE_DIR}/socks5_out.list"
        local s_json=$(printf '%s\n' "${s5_domains[@]}" | jq -R . | jq -s . | sed 's/null//g')
        if [[ "$s_json" != "[]" && -n "$s_json" ]]; then socks5_rules="{ \"domain\": ${s_json}, \"outbound\": \"socks5-out\" },"; fi
    fi
    
    if [[ "${PRISM_SOCKS5_IN_ENABLE:-}" == "true" ]] && [[ -s "${RULE_DIR}/socks5_in.list" ]]; then
         local s5in_domains=(); mapfile -t s5in_domains < "${RULE_DIR}/socks5_in.list"
         local sin_json=$(printf '%s\n' "${s5in_domains[@]}" | jq -R . | jq -s . | sed 's/null//g')
         if [[ "$sin_json" != "[]" ]]; then
             socks5_rules+="{ \"inbound\": [\"socks5-in\"], \"domain\": ${sin_json}, \"outbound\": \"direct\" }, { \"inbound\": [\"socks5-in\"], \"outbound\": \"block\" },"
         fi
    fi

    if [[ -f "${RULE_DIR}/ipv6.list" ]]; then
        local ipv6_domains=(); mapfile -t ipv6_domains < "${RULE_DIR}/ipv6.list"
        local v6_json=$(printf '%s\n' "${ipv6_domains[@]}" | jq -R . | jq -s . | sed 's/null//g')
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
    local cert_info=$(get_cert_paths "acme")

    if [[ "${PRISM_ENABLE_REALITY_VISION:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/04_inbounds_reality_vision.json" <<EOF
{ "inbounds": [{ "type": "vless", "tag": "vless-reality-vision", "listen": "::", "listen_port": ${PRISM_PORT_REALITY_VISION:-443}, "users": [{ "uuid": "${PRISM_UUID:-}", "flow": "xtls-rprx-vision" }], "tls": { "enabled": true, "server_name": "${PRISM_DEST:-}", "reality": { "enabled": true, "handshake": { "server": "${PRISM_DEST:-}", "server_port": ${PRISM_DEST_PORT:-443} }, "private_key": "${PRISM_PRIVATE_KEY:-}", "short_id": ["${PRISM_SHORT_ID:-}"] } } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_REALITY_GRPC:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/04_inbounds_reality_grpc.json" <<EOF
{ "inbounds": [{ "type": "vless", "tag": "vless-reality-grpc", "listen": "::", "listen_port": ${PRISM_PORT_REALITY_GRPC:-8443}, "users": [{ "uuid": "${PRISM_UUID:-}" }], "transport": { "type": "grpc", "service_name": "grpc" }, "tls": { "enabled": true, "server_name": "${PRISM_DEST:-}", "reality": { "enabled": true, "handshake": { "server": "${PRISM_DEST:-}", "server_port": ${PRISM_DEST_PORT:-443} }, "private_key": "${PRISM_PRIVATE_KEY:-}", "short_id": ["${PRISM_SHORT_ID:-}"] } } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_HY2:-}" == "true" ]]; then
        local cert_info=$(get_cert_paths "${PRISM_HY2_CERT_MODE:-acme}")
        local crt_path=$(echo "$cert_info" | cut -d'|' -f1); local key_path=$(echo "$cert_info" | cut -d'|' -f2)
        cat > "${PARTS_DIR}/04_inbounds_hy2.json" <<EOF
{ "inbounds": [{ "type": "hysteria2", "tag": "hy2-in", "listen": "::", "listen_port": ${PRISM_PORT_HY2:-8888}, "users": [{ "password": "${PRISM_HY2_PASSWORD:-}" }], "tls": { "enabled": true, "certificate_path": "${crt_path}", "key_path": "${key_path}" } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_TUIC:-}" == "true" ]]; then
        local cert_info=$(get_cert_paths "${PRISM_TUIC_CERT_MODE:-acme}")
        local crt_path=$(echo "$cert_info" | cut -d'|' -f1); local key_path=$(echo "$cert_info" | cut -d'|' -f2)
        cat > "${PARTS_DIR}/04_inbounds_tuic.json" <<EOF
{ "inbounds": [{ "type": "tuic", "tag": "tuic-in", "listen": "::", "listen_port": ${PRISM_PORT_TUIC:-9999}, "users": [{ "uuid": "${PRISM_TUIC_UUID:-}", "password": "${PRISM_TUIC_PASSWORD:-}" }], "congestion_control": "bbr", "tls": { "enabled": true, "certificate_path": "${crt_path}", "key_path": "${key_path}" } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_ANYTLS:-}" == "true" ]]; then
        local cert_info=$(get_cert_paths "${PRISM_ANYTLS_CERT_MODE:-acme}")
        local crt_path=$(echo "$cert_info" | cut -d'|' -f1); local key_path=$(echo "$cert_info" | cut -d'|' -f2)
        cat > "${PARTS_DIR}/04_inbounds_anytls.json" <<EOF
{ "inbounds": [{ "type": "anytls", "tag": "anytls-in", "listen": "::", "listen_port": ${PRISM_PORT_ANYTLS:-10443}, "users": [{ "password": "${PRISM_ANYTLS_PASSWORD:-}" }], "tls": { "enabled": true, "certificate_path": "${crt_path}", "key_path": "${key_path}" } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_ANYTLS_REALITY:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/04_inbounds_anytls_reality.json" <<EOF
{ "inbounds": [{ "type": "anytls", "tag": "anytls-reality-in", "listen": "::", "listen_port": ${PRISM_PORT_ANYTLS_REALITY:-20443}, "users": [{ "password": "${PRISM_ANYTLS_REALITY_PASSWORD:-}" }], "tls": { "enabled": true, "server_name": "${PRISM_DEST:-}", "reality": { "enabled": true, "handshake": { "server": "${PRISM_DEST:-}", "server_port": ${PRISM_DEST_PORT:-443} }, "private_key": "${PRISM_PRIVATE_KEY:-}", "short_id": ["${PRISM_SHORT_ID:-}"] } } }] }
EOF
    fi

    if [[ "${PRISM_ENABLE_SHADOWTLS:-}" == "true" ]]; then
        cat > "${PARTS_DIR}/04_inbounds_shadowtls.json" <<EOF
{ "inbounds": [ { "type": "shadowtls", "tag": "shadowtls-in", "listen": "::", "listen_port": ${PRISM_PORT_SHADOWTLS:-30443}, "version": 3, "users": [{ "password": "${PRISM_SHADOWTLS_PASSWORD:-}" }], "handshake": { "server": "${PRISM_DEST:-www.microsoft.com}", "server_port": 443 }, "detour": "vless-inner" }, { "type": "vless", "tag": "vless-inner", "listen": "127.0.0.1", "listen_port": ${PRISM_PORT_INNER_VLESS:-40443}, "users": [{ "uuid": "${PRISM_UUID:-}" }] } ] }
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
    export ENABLE_DEPRECATED_WIREGUARD_OUTBOUND=true
    if jq -s 'reduce .[] as $item ({}; . * $item + 
        (if ($item | has("inbounds")) and (. | has("inbounds")) then {"inbounds": (.inbounds + $item.inbounds)} else {} end) +
        (if ($item | has("outbounds")) and (. | has("outbounds")) then {"outbounds": (.outbounds + $item.outbounds)} else {} end) +
        (if ($item | has("route")) and (. | has("route")) and ($item.route | has("rules")) and (.route | has("rules")) then {"route": {"rules": (.route.rules + $item.route.rules)}} else {} end)
    )' ${PARTS_DIR}/*.json > "${output_file}"; then
        success "配置文件已生成"
        local check_out
        if check_out=$(ENABLE_DEPRECATED_WIREGUARD_OUTBOUND=true ${SINGBOX_BIN} check -c "${output_file}" 2>&1); then success "配置驗證通過 (Valid)"; else error "配置驗證失敗！"; echo -e "${R}${check_out}${N}"; return 1; fi
    else error "配置文件合併失敗"; exit 1; fi
}

build_config() {
    init_config_structure; manage_secrets; gen_log_config; gen_dns_config; gen_outbounds_config; gen_route_config; gen_inbounds_config; merge_configs
}