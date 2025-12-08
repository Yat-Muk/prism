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

init_config_structure() { 
    mkdir -p "${PARTS_DIR}"
    rm -f "${PARTS_DIR}"/*.json
}

write_json_file() {
    echo "$1" > "${TEMP_DIR}/$2"
}

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

is_legacy_core() {
    if [[ ! -x "${SINGBOX_BIN}" ]]; then return 1; fi
    local ver=$(${SINGBOX_BIN} version 2>/dev/null | grep "sing-box version" | awk '{print $3}')
    ver=${ver#v}
    local main_ver=$(echo "$ver" | cut -d- -f1)
    local major=$(echo "$main_ver" | cut -d. -f1)
    local minor=$(echo "$main_ver" | cut -d. -f2)

    if [[ "$major" -eq 1 && "$minor" -lt 12 ]]; then return 0; fi
    return 1
}

get_padding_scheme_json() {
    case "${PRISM_ANYTLS_PADDING_MODE:-balanced}" in
        "minimal") echo '["stop=4", "0=15-35", "1=10-50", "2=100-200"]' ;;
        "high_resistance") echo '["stop=10", "0=50-100", "1=500-800", "2=c,800-1200", "3=50-50", "4=c,1000-1500", "5=100-500"]' ;;
        "official") echo '["stop=8", "0=30-30", "1=100-400", "2=400-500,c,500-1000,c,500-1000,c,500-1000,c,500-1000", "3=9-9,500-1000", "4=500-1000", "5=500-1000", "6=500-1000", "7=500-1000"]' ;;
        *) echo '["stop=6", "0=10-60", "1=30-150", "2=200-500,c,400-800", "3=100-300", "4=500-1200"]' ;;
    esac
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

    if [[ -z "${PRISM_GLOBAL_PASSWORD}" ]]; then
        local global_pass=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 32)
        set_env_default "PRISM_GLOBAL_PASSWORD" "$global_pass"
    fi
    source "${SECRETS_FILE}"

    if [[ -z "${PRISM_UUID}" ]]; then
        local new_uuid=$(${SINGBOX_BIN} generate uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)
        set_env_default "PRISM_UUID" "$new_uuid"
    fi
    if [[ -z "${PRISM_TUIC_UUID}" ]]; then set_env_default "PRISM_TUIC_UUID" "${PRISM_UUID}"; fi

    if [[ -z "${PRISM_PRIVATE_KEY}" ]]; then
        local keypair=$(${SINGBOX_BIN} generate reality-keypair 2>/dev/null)
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
    set_env_default "PRISM_SOCKS5_IN_PORT" "$(get_random_port)"

    set_env_default "PRISM_HY2_PASSWORD" "${PRISM_GLOBAL_PASSWORD}"
    set_env_default "PRISM_TUIC_PASSWORD" "${PRISM_GLOBAL_PASSWORD}"
    set_env_default "PRISM_ANYTLS_PASSWORD" "${PRISM_GLOBAL_PASSWORD}"
    set_env_default "PRISM_ANYTLS_REALITY_PASSWORD" "${PRISM_GLOBAL_PASSWORD}"
    set_env_default "PRISM_SHADOWTLS_PASSWORD" "${PRISM_GLOBAL_PASSWORD}"

    if [[ -z "${PRISM_SS_PASSWORD}" ]]; then
        local ss_key=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
        set_env_default "PRISM_SS_PASSWORD" "$ss_key"
    fi
    set_env_default "PRISM_SOCKS5_IN_USER" "prism"
    set_env_default "PRISM_SOCKS5_IN_PASS" "${PRISM_GLOBAL_PASSWORD}"
    set_env_default "PRISM_ANYTLS_PADDING_MODE" "balanced"

    if ! grep -q "PRISM_ENABLE_" "${SECRETS_FILE}"; then
        set_env_default "PRISM_ENABLE_REALITY_VISION" "true"
        set_env_default "PRISM_ENABLE_HY2" "true"
        set_env_default "PRISM_ENABLE_TUIC" "true"
        set_env_default "PRISM_ENABLE_REALITY_GRPC" "false"
        set_env_default "PRISM_ENABLE_ANYTLS" "false"
        set_env_default "PRISM_ENABLE_ANYTLS_REALITY" "false"
        set_env_default "PRISM_ENABLE_SHADOWTLS" "false"
        set_env_default "PRISM_SOCKS5_IN_ENABLE" "false"
    fi
    set_env_default "PRISM_OUTBOUND_MODE" "prefer_ipv4"
    source "${SECRETS_FILE}"
}

gen_log_config() {
    jq -n --arg output "${WORK_DIR}/box.log" '{log: {level: "info", output: $output, timestamp: true}}' > "${PARTS_DIR}/00_log.json"
}

gen_dns_config() {
    write_json_file "[]" "sni_rules.json"

    if [[ "${PRISM_SNI_ENABLE:-}" == "true" && -n "${PRISM_SNI_IP:-}" ]] && [[ -f "${RULE_DIR}/sni.list" ]]; then
        if [[ -s "${RULE_DIR}/sni.list" ]]; then
            jq -R . "${RULE_DIR}/sni.list" | jq -s . > "${TEMP_DIR}/domains.json"
            if [[ -s "${TEMP_DIR}/domains.json" ]]; then
                jq -n --arg ip "${PRISM_SNI_IP}" --slurpfile d "${TEMP_DIR}/domains.json" \
                    '[{domain: $d[0], rewrite_ip_address: [$ip]}]' > "${TEMP_DIR}/sni_rules.json"
            fi
        fi
    fi

    if is_legacy_core; then
        jq -n --arg mode "${PRISM_OUTBOUND_MODE:-prefer_ipv4}" --slurpfile sni "${TEMP_DIR}/sni_rules.json" \
        '{dns: {servers: [{tag: "dns_google", address: "8.8.8.8"}, {tag: "dns_local", address: "local"}], rules: ($sni[0] + [{rule_set: "geosite-cn", server: "dns_local"}]), final: "dns_google", strategy: $mode}}' \
        > "${PARTS_DIR}/01_dns.json"
    else
        jq -n --slurpfile sni "${TEMP_DIR}/sni_rules.json" \
        '{dns: {servers: [{tag: "dns_google", server: "8.8.8.8", type: "udp"}, {tag: "dns_local", type: "local"}], rules: ($sni[0] + [{rule_set: "geosite-cn", server: "dns_local"}]), final: "dns_google"}}' \
        > "${PARTS_DIR}/01_dns.json"
    fi
    rm -f "${TEMP_DIR}/domains.json" "${TEMP_DIR}/sni_rules.json"
}

gen_outbounds_config() {
    if is_legacy_core; then
        jq -n '{outbounds: [{type: "direct", tag: "direct"}, {type: "block", tag: "block"}, {type: "dns", tag: "dns-out"}]}' > "${PARTS_DIR}/02_outbounds_base.json"
    else
        jq -n '{outbounds: [{type: "direct", tag: "direct"}]}' > "${PARTS_DIR}/02_outbounds_base.json"
    fi
    
    if is_legacy_core; then
        jq -n '{outbounds: [{type: "direct", tag: "ipv6-out", domain_strategy: "ipv6_only"}]}' > "${PARTS_DIR}/02_outbounds_ipv6.json"
    else
        jq -n '{outbounds: [{type: "direct", tag: "ipv6-out"}]}' > "${PARTS_DIR}/02_outbounds_ipv6.json"
    fi

    if [[ "${PRISM_WARP_ENABLE:-}" == "true" ]]; then
        write_json_file "${PRISM_WARP_RESERVED:-[0,0,0]}" "reserved.json"
        jq -n --arg pk "${PRISM_WARP_PRIVATE_KEY:-}" --arg peer "${PRISM_WARP_PUBLIC_KEY:-}" --arg ipv6 "${PRISM_WARP_IPV6_ADDR:-}" \
           --slurpfile res "${TEMP_DIR}/reserved.json" \
           '{outbounds: [{type: "wireguard", tag: "warp-out", server: "162.159.192.1", server_port: 2408, local_address: ["172.16.0.2/32", ($ipv6 + "/128")], private_key: $pk, peer_public_key: $peer, reserved: $res[0], mtu: 1280}]}' > "${PARTS_DIR}/02_outbounds_warp.json"
    fi

    if [[ "${PRISM_SOCKS5_OUT_ENABLE:-}" == "true" ]]; then
        jq -n --arg srv "${PRISM_SOCKS5_OUT_IP:-127.0.0.1}" --arg port "${PRISM_SOCKS5_OUT_PORT:-1080}" --arg user "${PRISM_SOCKS5_OUT_USER:-}" --arg pass "${PRISM_SOCKS5_OUT_PASS:-}" \
           '{outbounds: [{type: "socks", tag: "socks5-out", server: $srv, server_port: ($port|tonumber), version: "5", username: $user, password: $pass}]}' > "${PARTS_DIR}/02_outbounds_socks5.json"
    fi
}

gen_route_config() {
    local rules_file="${TEMP_DIR}/route_rules.json"
    echo "[]" > "$rules_file"

    local final_outbound="direct"
    if [[ "${PRISM_WARP_GLOBAL:-}" == "true" ]]; then final_outbound="warp-out"; fi
    if [[ "${PRISM_SOCKS5_OUT_GLOBAL:-}" == "true" ]]; then final_outbound="socks5-out"; fi
    if [[ "${PRISM_IPV6_GLOBAL:-}" == "true" ]]; then final_outbound="ipv6-out"; fi

    append_rule() {
        local file=$1; local out=$2
        if [[ -f "$file" && -s "$file" ]]; then
            jq -R . "$file" | jq -s . > "${TEMP_DIR}/tmp_list.json"
            jq -n --arg out "$out" --slurpfile d "${TEMP_DIR}/tmp_list.json" '{domain: $d[0], outbound: $out}' > "${TEMP_DIR}/tmp_rule.json"
            jq -s '.[0] + [.[1]]' "$rules_file" "${TEMP_DIR}/tmp_rule.json" > "${rules_file}.tmp" && mv "${rules_file}.tmp" "$rules_file"
        fi
    }

    if [[ "${PRISM_WARP_ENABLE:-}" == "true" ]]; then append_rule "${RULE_DIR}/warp.list" "warp-out"; fi
    if [[ "${PRISM_SOCKS5_OUT_ENABLE:-}" == "true" ]]; then append_rule "${RULE_DIR}/socks5_out.list" "socks5-out"; fi
    if [[ -f "${RULE_DIR}/ipv6.list" ]]; then append_rule "${RULE_DIR}/ipv6.list" "ipv6-out"; fi

    if [[ "${PRISM_SOCKS5_IN_ENABLE:-}" == "true" && -s "${RULE_DIR}/socks5_in.list" ]]; then
         jq -R . "${RULE_DIR}/socks5_in.list" | jq -s . > "${TEMP_DIR}/tmp_s5.json"
         
         if is_legacy_core; then
             jq -n --slurpfile d "${TEMP_DIR}/tmp_s5.json" \
                '[{inbound: ["socks5-in"], domain: $d[0], outbound: "direct"}, {inbound: ["socks5-in"], outbound: "block"}]' > "${TEMP_DIR}/tmp_s5_rules.json"
         else
             jq -n --slurpfile d "${TEMP_DIR}/tmp_s5.json" \
                '[{inbound: ["socks5-in"], domain: $d[0], outbound: "direct"}, {inbound: ["socks5-in"], action: "reject"}]' > "${TEMP_DIR}/tmp_s5_rules.json"
         fi
         jq -s '.[0] + .[1]' "$rules_file" "${TEMP_DIR}/tmp_s5_rules.json" > "${rules_file}.tmp" && mv "${rules_file}.tmp" "$rules_file"
    fi

    if is_legacy_core; then
        write_json_file '{"protocol": "dns", "outbound": "dns-out"}' "dns_rule.json"
        write_json_file '{"rule_set": "geosite-ads", "outbound": "block"}' "ad_rule.json"
    else
        write_json_file '{"protocol": "dns", "action": "hijack-dns"}' "dns_rule.json"
        write_json_file '{"rule_set": "geosite-ads", "action": "reject"}' "ad_rule.json"
    fi
    write_json_file '{"rule_set": ["geoip-cn", "geosite-cn"], "outbound": "direct"}' "cn_rule.json"
    
    cat > "${TEMP_DIR}/rulesets.json" <<EOF
[
  {"tag": "geosite-cn", "type": "remote", "format": "binary", "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs", "download_detour": "direct"},
  {"tag": "geoip-cn", "type": "remote", "format": "binary", "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs", "download_detour": "direct"},
  {"tag": "geosite-ads", "type": "remote", "format": "binary", "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs", "download_detour": "direct"}
]
EOF

    if is_legacy_core; then
        jq -n --arg final "$final_outbound" \
           --slurpfile r_dns "${TEMP_DIR}/dns_rule.json" \
           --slurpfile r_ad "${TEMP_DIR}/ad_rule.json" \
           --slurpfile r_cn "${TEMP_DIR}/cn_rule.json" \
           --slurpfile custom "$rules_file" \
           --slurpfile rs "${TEMP_DIR}/rulesets.json" \
           '{route: {rule_set: $rs[0], rules: ([$r_dns[0]] + $custom[0] + [$r_ad[0], $r_cn[0]]), final: $final, auto_detect_interface: true}}' \
           > "${PARTS_DIR}/03_route.json"
    else
        jq -n --arg final "$final_outbound" \
           --slurpfile r_dns "${TEMP_DIR}/dns_rule.json" \
           --slurpfile r_ad "${TEMP_DIR}/ad_rule.json" \
           --slurpfile r_cn "${TEMP_DIR}/cn_rule.json" \
           --slurpfile custom "$rules_file" \
           --slurpfile rs "${TEMP_DIR}/rulesets.json" \
           '{route: {rule_set: $rs[0], rules: ([$r_dns[0]] + $custom[0] + [$r_ad[0], $r_cn[0]]), final: $final, auto_detect_interface: true, default_domain_resolver: {server: "dns_google"}}}' \
           > "${PARTS_DIR}/03_route.json"
    fi
    
    rm -f "${TEMP_DIR}/tmp_"* "$rules_file" "${TEMP_DIR}/rulesets.json" "${TEMP_DIR}/"*.json
}

gen_inbounds_config() {
    rm -f "${PARTS_DIR}/04_inbounds"*.json
    
    if [[ "${PRISM_ENABLE_REALITY_VISION:-}" == "true" ]]; then
        jq -n --arg port "${PRISM_PORT_REALITY_VISION}" --arg uuid "${PRISM_UUID}" \
           --arg dest "${PRISM_DEST}" --arg dest_port "${PRISM_DEST_PORT}" --arg pk "${PRISM_PRIVATE_KEY}" --arg sid "${PRISM_SHORT_ID}" \
           '{inbounds: [{type: "vless", tag: "vless-reality-vision", listen: "::", listen_port: ($port|tonumber), users: [{uuid: $uuid, flow: "xtls-rprx-vision"}], tls: {enabled: true, server_name: $dest, reality: {enabled: true, handshake: {server: $dest, server_port: ($dest_port|tonumber)}, private_key: $pk, short_id: [$sid]}}}]}' > "${PARTS_DIR}/04_inbounds_reality_vision.json"
    fi

    if [[ "${PRISM_ENABLE_REALITY_GRPC:-}" == "true" ]]; then
        jq -n --arg port "${PRISM_PORT_REALITY_GRPC}" --arg uuid "${PRISM_UUID}" \
           --arg dest "${PRISM_DEST}" --arg dest_port "${PRISM_DEST_PORT}" --arg pk "${PRISM_PRIVATE_KEY}" --arg sid "${PRISM_SHORT_ID}" \
           '{inbounds: [{type: "vless", tag: "vless-reality-grpc", listen: "::", listen_port: ($port|tonumber), users: [{uuid: $uuid}], transport: {type: "grpc", service_name: "grpc"}, tls: {enabled: true, server_name: $dest, reality: {enabled: true, handshake: {server: $dest, server_port: ($dest_port|tonumber)}, private_key: $pk, short_id: [$sid]}}}]}' > "${PARTS_DIR}/04_inbounds_reality_grpc.json"
    fi

    if [[ "${PRISM_ENABLE_HY2:-}" == "true" ]]; then
        local cert_info=$(get_cert_paths "${PRISM_HY2_CERT_MODE:-self_signed}")
        local crt_path=$(echo "$cert_info" | cut -d'|' -f1); local key_path=$(echo "$cert_info" | cut -d'|' -f2)
        jq -n --arg port "${PRISM_PORT_HY2}" --arg pwd "${PRISM_HY2_PASSWORD}" --arg crt "$crt_path" --arg key "$key_path" \
           '{inbounds: [{type: "hysteria2", tag: "hy2-in", listen: "::", listen_port: ($port|tonumber), users: [{password: $pwd}], ignore_client_bandwidth: false, tls: {enabled: true, alpn: ["h3"], certificate_path: $crt, key_path: $key}}]}' > "${PARTS_DIR}/04_inbounds_hy2.json"
    fi

    if [[ "${PRISM_ENABLE_TUIC:-}" == "true" ]]; then
        local cert_info=$(get_cert_paths "${PRISM_TUIC_CERT_MODE:-self_signed}")
        local crt_path=$(echo "$cert_info" | cut -d'|' -f1); local key_path=$(echo "$cert_info" | cut -d'|' -f2)
        jq -n --arg port "${PRISM_PORT_TUIC}" --arg uuid "${PRISM_TUIC_UUID}" --arg pwd "${PRISM_TUIC_PASSWORD}" --arg crt "$crt_path" --arg key "$key_path" \
           '{inbounds: [{type: "tuic", tag: "tuic-in", listen: "::", listen_port: ($port|tonumber), users: [{uuid: $uuid, password: $pwd}], congestion_control: "bbr", tls: {enabled: true, alpn: ["h3"], certificate_path: $crt, key_path: $key}}]}' > "${PARTS_DIR}/04_inbounds_tuic.json"
    fi

    if [[ "${PRISM_ENABLE_ANYTLS:-}" == "true" ]]; then
        local cert_info=$(get_cert_paths "${PRISM_ANYTLS_CERT_MODE:-self_signed}")
        local crt_path=$(echo "$cert_info" | cut -d'|' -f1); local key_path=$(echo "$cert_info" | cut -d'|' -f2)
        write_json_file "$(get_padding_scheme_json)" "padding.json"
        
        jq -n --arg port "${PRISM_PORT_ANYTLS}" --arg pwd "${PRISM_ANYTLS_PASSWORD}" --arg sni "${PRISM_ACME_DOMAIN:-www.bing.com}" \
           --arg crt "$crt_path" --arg key "$key_path" --slurpfile pad "${TEMP_DIR}/padding.json" \
           '{inbounds: [{type: "anytls", tag: "anytls-in", listen: "::", listen_port: ($port|tonumber), users: [{name: "prism", password: $pwd}], padding_scheme: $pad[0], tls: {enabled: true, server_name: $sni, certificate_path: $crt, key_path: $key}}]}' > "${PARTS_DIR}/04_inbounds_anytls.json"
    fi

    if [[ "${PRISM_ENABLE_ANYTLS_REALITY:-}" == "true" ]]; then
        write_json_file "$(get_padding_scheme_json)" "padding.json"
        jq -n --arg port "${PRISM_PORT_ANYTLS_REALITY}" --arg pwd "${PRISM_ANYTLS_REALITY_PASSWORD}" --arg dest "${PRISM_DEST}" \
           --arg dest_port "${PRISM_DEST_PORT}" --arg pk "${PRISM_PRIVATE_KEY}" --arg sid "${PRISM_SHORT_ID}" --slurpfile pad "${TEMP_DIR}/padding.json" \
           '{inbounds: [{type: "anytls", tag: "anytls-reality-in", listen: "::", listen_port: ($port|tonumber), users: [{name: "prism", password: $pwd}], padding_scheme: $pad[0], tls: {enabled: true, server_name: $dest, reality: {enabled: true, handshake: {server: $dest, server_port: ($dest_port|tonumber)}, private_key: $pk, short_id: [$sid]}}}]}' > "${PARTS_DIR}/04_inbounds_anytls_reality.json"
    fi

    if [[ "${PRISM_ENABLE_SHADOWTLS:-}" == "true" ]]; then
        jq -n --arg port "${PRISM_PORT_SHADOWTLS}" --arg pwd "${PRISM_SHADOWTLS_PASSWORD}" --arg dest "${PRISM_DEST}" --arg inner_port "${PRISM_PORT_INNER_VLESS}" --arg ss_pwd "${PRISM_SS_PASSWORD}" \
           '{inbounds: [{type: "shadowtls", tag: "shadowtls-in", listen: "::", listen_port: ($port|tonumber), version: 3, users: [{password: $pwd}], handshake: {server: $dest, server_port: 443}, detour: "ss-inner"}, {type: "shadowsocks", tag: "ss-inner", listen: "127.0.0.1", listen_port: ($inner_port|tonumber), method: "2022-blake3-aes-128-gcm", password: $ss_pwd}]}' > "${PARTS_DIR}/04_inbounds_shadowtls.json"
    fi
    
    if [[ "${PRISM_SOCKS5_IN_ENABLE:-}" == "true" ]]; then
        jq -n --arg port "${PRISM_SOCKS5_IN_PORT:-10808}" --arg user "${PRISM_SOCKS5_IN_USER:-prism}" --arg pass "${PRISM_SOCKS5_IN_PASS:-prism}" \
           '{inbounds: [{type: "socks", tag: "socks5-in", listen: "::", listen_port: ($port|tonumber), users: [{username: $user, password: $pass}]}]}' > "${PARTS_DIR}/04_inbounds_socks5.json"
    fi
    rm -f "${TEMP_DIR}/padding.json"
}

merge_configs() {
    local output_file="${CONFIG_DIR}/config.json"
    if ! command -v jq &> /dev/null; then error "缺少 jq 工具。"; exit 1; fi
    
    export ENABLE_DEPRECATED_WIREGUARD_OUTBOUND=true
    export ENABLE_DEPRECATED_LEGACY_DNS_SERVERS=true
    export ENABLE_DEPRECATED_LEGACY_DOMAIN_STRATEGY_OPTIONS=true
    export ENABLE_DEPRECATED_SPECIAL_OUTBOUNDS=true
    
    jq -s '
      {
        log: (map(.log) | add),
        dns: (map(.dns) | add),
        # 數組字段：追加
        inbounds: (map(.inbounds) | flatten | map(select(. != null)) | unique_by(.tag)),
        outbounds: (map(.outbounds) | flatten | map(select(. != null)) | unique_by(.tag)),
        # 對象字段：取最後一個非空的 (route 包含 rule_set)
        route: (map(select(.route != null) | .route) | last)
      }
    ' "${PARTS_DIR}"/*.json > "${output_file}"

    if [[ -s "${output_file}" ]]; then
        local check_out
        check_out=$(${SINGBOX_BIN} check -c "${output_file}" 2>&1)
        if [[ $? -eq 0 ]]; then 
            success "配置生成並驗證通過"
        else 
            error "Sing-box 核心校驗失敗"
            echo -e "${R}${check_out}${N}"
            return 1
        fi
    else 
        error "配置文件合併失敗 (Output empty)"
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