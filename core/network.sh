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

get_public_ip() {
    local version=$1
    local ip=""
    
    ip=$(curl -s "$version" --max-time 3 ipinfo.io/ip 2>/dev/null)
    
    if [[ -z "$ip" ]]; then
        local host="api.ipify.org"
        if [[ "$version" == "-6" ]]; then host="api64.ipify.org"; fi
        ip=$(curl -s "$version" --max-time 3 "$host" 2>/dev/null)
    fi
    
    if [[ -z "$ip" ]]; then
        ip=$(curl -s "$version" --max-time 3 ifconfig.co 2>/dev/null)
    fi
    
    if [[ "$version" == "-4" ]]; then
        if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo ""; return; fi
    elif [[ "$version" == "-6" ]]; then
        if [[ ! "$ip" =~ : ]]; then echo ""; return; fi
    fi

    echo "$ip"
}

check_network_stack() {
    local has_v4_iface=$(ip -4 addr show scope global)
    local has_v6_iface=$(ip -6 addr show scope global)
    
    IPV4_ADDR=""
    IPV6_ADDR=""
    NETWORK_STACK="unknown"

    if [[ -n "$has_v4_iface" ]]; then
        IPV4_ADDR=$(get_public_ip "-4")
    fi
    
    if [[ -n "$has_v6_iface" ]]; then
        IPV6_ADDR=$(get_public_ip "-6")
    fi

    if [[ -n "$IPV4_ADDR" && -n "$IPV6_ADDR" ]]; then
        NETWORK_STACK="dual"
    elif [[ -n "$IPV4_ADDR" ]]; then
        NETWORK_STACK="ipv4"
    elif [[ -n "$IPV6_ADDR" ]]; then
        NETWORK_STACK="ipv6"
    fi
    
    export IPV4_ADDR
    export IPV6_ADDR
    export NETWORK_STACK
}

open_port() {
    local port=$1
    local proto=$2
    local comment="prism_allow"

    if [[ -z "$port" || "$port" == "0" ]]; then return; fi
    
    if [[ "$proto" == "tcp" || "$proto" == "both" ]]; then
        if ! iptables -C INPUT -p tcp --dport "$port" -m comment --comment "$comment" -j ACCEPT 2>/dev/null; then
            iptables -A INPUT -p tcp --dport "$port" -m comment --comment "$comment" -j ACCEPT
        fi
    fi

    if [[ "$proto" == "udp" || "$proto" == "both" ]]; then
        if ! iptables -C INPUT -p udp --dport "$port" -m comment --comment "$comment" -j ACCEPT 2>/dev/null; then
            iptables -A INPUT -p udp --dport "$port" -m comment --comment "$comment" -j ACCEPT
        fi
    fi
}

init_iptables_chain() {
    if ! command -v iptables &> /dev/null; then return; fi
    local chain_name="PRISM_HOPPING"
    
    iptables -t nat -N "${chain_name}" 2>/dev/null

    if ! iptables -t nat -C PREROUTING -p udp -j "${chain_name}" 2>/dev/null; then
        iptables -t nat -A PREROUTING -p udp -j "${chain_name}"
    fi
}

add_hopping_rule() {
    local start=$1; local end=$2; local target_port=$3
    local chain_name="PRISM_HOPPING"

    if [[ -n "$start" && -n "$end" && "$start" != "0" ]]; then
        iptables -t nat -A "${chain_name}" -p udp --dport "${start}:${end}" -j REDIRECT --to-ports "${target_port}"   
        iptables -A INPUT -p udp --dport "${start}:${end}" -m comment --comment "prism_allow" -j ACCEPT
    fi
}

flush_firewall_rules() {
    if ! command -v iptables &> /dev/null; then return; fi

    iptables -S INPUT | grep "prism_allow" | sed 's/^-A/-D/' | while read -r rule; do
        iptables $rule >/dev/null 2>&1
    done

    local chain_name="PRISM_HOPPING"
    iptables -t nat -S PREROUTING | grep "${chain_name}" | sed 's/^-A/-D/' | while read -r rule; do
        iptables -t nat $rule >/dev/null 2>&1
    done

    iptables -t nat -F "${chain_name}" 2>/dev/null
    iptables -t nat -X "${chain_name}" 2>/dev/null

    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save >/dev/null 2>&1
    fi
}

apply_firewall_rules() {
    local conf_file="${CONFIG_DIR}/secrets.env"
    if [[ -z "${CONFIG_DIR}" ]]; then
        conf_file="/etc/prism/conf/secrets.env"
    fi

    if [[ ! -f "$conf_file" ]]; then
        error "防火牆更新失敗：找不到配置文件 ($conf_file)"
        return 1
    fi

    source "$conf_file"
    
    if ! command -v iptables &> /dev/null; then return; fi

    info "正在更新防火牆規則..."

    flush_firewall_rules

    init_iptables_chain

    if [[ "${PRISM_ENABLE_REALITY_VISION:-false}" == "true" ]]; then
        open_port "${PRISM_PORT_REALITY_VISION}" "tcp"
    fi

    if [[ "${PRISM_ENABLE_REALITY_GRPC:-false}" == "true" ]]; then
        open_port "${PRISM_PORT_REALITY_GRPC}" "tcp"
    fi

    if [[ "${PRISM_ENABLE_HY2:-false}" == "true" ]]; then
        open_port "${PRISM_PORT_HY2}" "udp"
    fi

    if [[ "${PRISM_ENABLE_TUIC:-false}" == "true" ]]; then
        open_port "${PRISM_PORT_TUIC}" "udp"
    fi

    if [[ "${PRISM_ENABLE_ANYTLS:-false}" == "true" ]]; then
        open_port "${PRISM_PORT_ANYTLS}" "tcp"
    fi

    if [[ "${PRISM_ENABLE_ANYTLS_REALITY:-false}" == "true" ]]; then
        open_port "${PRISM_PORT_ANYTLS_REALITY}" "tcp"
    fi

    if [[ "${PRISM_ENABLE_SHADOWTLS:-false}" == "true" ]]; then
        open_port "${PRISM_PORT_SHADOWTLS}" "tcp"
    fi
    
    if [[ "${PRISM_SOCKS5_IN_ENABLE:-false}" == "true" ]]; then
        open_port "${PRISM_SOCKS5_IN_PORT}" "both"
    fi

    if [[ "${PRISM_ENABLE_HY2:-false}" == "true" && -n "${PRISM_HY2_PORT_HOPPING:-}" ]]; then
        local start=$(echo "${PRISM_HY2_PORT_HOPPING}" | cut -d: -f1)
        local end=$(echo "${PRISM_HY2_PORT_HOPPING}" | cut -d: -f2)
        add_hopping_rule "$start" "$end" "${PRISM_PORT_HY2}"
    fi

    if [[ "${PRISM_ENABLE_TUIC:-false}" == "true" && -n "${PRISM_TUIC_PORT_HOPPING:-}" ]]; then
        local start=$(echo "${PRISM_TUIC_PORT_HOPPING}" | cut -d: -f1)
        local end=$(echo "${PRISM_TUIC_PORT_HOPPING}" | cut -d: -f2)
        add_hopping_rule "$start" "$end" "${PRISM_PORT_TUIC}"
    fi
    
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save >/dev/null 2>&1
    fi
    
    success "防火牆規則已更新"
}