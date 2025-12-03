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

check_network_stack() {
    if [[ -n $(ip -4 addr show scope global) ]]; then
        if [[ -n $(ip -6 addr show scope global) ]]; then
            NETWORK_STACK="dual"
            IPV4_ADDR=$(curl -s4m2 https://api.ipify.org)
            IPV6_ADDR=$(curl -s6m2 https://api64.ipify.org)
        else
            NETWORK_STACK="ipv4"
            IPV4_ADDR=$(curl -s4m2 https://api.ipify.org)
        fi
    else
        NETWORK_STACK="ipv6"
        IPV6_ADDR=$(curl -s6m2 https://api64.ipify.org)
    fi
}

apply_iptables_rule() {
    local proto=$1
    local start=$2
    local end=$3
    local target=$4
    local comment="prism_$5"

    if ! command -v iptables &> /dev/null; then return; fi

    iptables -t nat -S PREROUTING | grep "$comment" | sed 's/-A/-D/' | while read -r rule; do
        iptables -t nat $rule >/dev/null 2>&1
    done
    
    iptables -S INPUT | grep "$comment" | sed 's/-A/-D/' | while read -r rule; do
        iptables $rule >/dev/null 2>&1
    done

    if [[ -n "$start" && -n "$end" && "$start" != "0" ]]; then
        iptables -t nat -A PREROUTING -p $proto --dport "$start:$end" -m comment --comment "$comment" -j REDIRECT --to-ports "$target"
        iptables -A INPUT -p $proto --dport "$start:$end" -m comment --comment "$comment" -j ACCEPT
    fi
}

update_all_port_hopping() {
    if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi
    
    if [[ "${PRISM_ENABLE_HY2:-false}" == "true" && -n "${PRISM_HY2_PORT_HOPPING:-}" ]]; then
        local start=$(echo "${PRISM_HY2_PORT_HOPPING}" | cut -d- -f1)
        local end=$(echo "${PRISM_HY2_PORT_HOPPING}" | cut -d- -f2)
        apply_iptables_rule "udp" "$start" "$end" "${PRISM_PORT_HY2:-}" "hy2_hopping"
    else
        apply_iptables_rule "udp" "0" "0" "0" "hy2_hopping"
    fi

    if [[ "${PRISM_ENABLE_TUIC:-false}" == "true" && -n "${PRISM_TUIC_PORT_HOPPING:-}" ]]; then
        local start=$(echo "${PRISM_TUIC_PORT_HOPPING}" | cut -d- -f1)
        local end=$(echo "${PRISM_TUIC_PORT_HOPPING}" | cut -d- -f2)
        apply_iptables_rule "udp" "$start" "$end" "${PRISM_PORT_TUIC:-}" "tuic_hopping"
    else
        apply_iptables_rule "udp" "0" "0" "0" "tuic_hopping"
    fi
    
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save >/dev/null 2>&1
    fi
}