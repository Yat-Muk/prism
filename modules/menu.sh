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
source "${BASE_DIR}/core/sys.sh"
source "${BASE_DIR}/core/network.sh"

source "${BASE_DIR}/modules/menu_ops.sh"
source "${BASE_DIR}/modules/menu_config.sh"
source "${BASE_DIR}/modules/menu_info.sh"
source "${BASE_DIR}/modules/menu_cert.sh"

if [[ -f "${BASE_DIR}/modules/menu_routing.sh" ]]; then source "${BASE_DIR}/modules/menu_routing.sh"; else submenu_routing() { warn "開發中..."; sleep 1; show_menu; }; fi
if [[ -f "${BASE_DIR}/modules/menu_core.sh" ]]; then source "${BASE_DIR}/modules/menu_core.sh"; else submenu_core() { warn "開發中..."; sleep 1; show_menu; }; fi
if [[ -f "${BASE_DIR}/modules/menu_bbr.sh" ]]; then source "${BASE_DIR}/modules/menu_bbr.sh"; else action_bbr() { warn "開發中..."; sleep 1; show_menu; }; fi

if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi

get_core_status_str() {
    if [[ ! -f "${SINGBOX_BIN}" ]]; then
        echo "${D}未安裝${N}"
        return
    fi
    
    local local_ver=$(${SINGBOX_BIN} version 2>/dev/null | grep "sing-box version" | awk '{print $3}')
    echo "${G}${local_ver}${N}"
}

get_run_status_str() {
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet prism; then echo "${G}運行中${N}";
        elif systemctl is-failed --quiet prism; then echo "${R}已崩潰${N}";
        else echo "${D}已停止${N}"; fi
    else echo "${Y}未知${N}"; fi
}

show_menu() {
    if [[ -z "${OS_RELEASE}" ]]; then detect_os; fi
    if [[ -z "${NETWORK_STACK}" ]]; then check_network_stack; fi
    if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi

    local sys_info="${OS_RELEASE} ${OS_VERSION}"
    local kernel_info=$(uname -r | cut -d- -f1)
    local core_str=$(get_core_status_str)
    local run_str=$(get_run_status_str)
    
    local v4_str="${IPV4_ADDR:-${D}無${N}}"
    local v6_str="${IPV6_ADDR:-${D}無${N}}"
    
    local out_mode="IPv4 優先"
    case "${PRISM_OUTBOUND_MODE:-prefer_ipv4}" in
        prefer_ipv6) out_mode="IPv6 優先" ;;
        ipv4_only) out_mode="僅 IPv4" ;;
        ipv6_only) out_mode="僅 IPv6" ;;
    esac

    print_banner
    
    print_kv "System" "${sys_info}"
    print_kv "Kernel" "${kernel_info}"
    print_kv "Sing-box" "${core_str}"
    print_kv "Status" "${run_str}"
    echo -e "${SEP_LINE}"
    
    print_kv "IPv4" "${v4_str}"
    print_kv "IPv6" "${v6_str}"
    print_kv "Outbound" "${Y}${out_mode}${N}"
    echo -e "${SEP_LINE}"

    echo -e " ${B}[ 基礎管理 ]${N}"
    if [[ -f "${SINGBOX_BIN}" ]]; then
        print_entry "1" "更新/重裝 Prism"
    else
        print_entry "1" "${G}開始安裝 Prism${N}"
    fi
    print_entry "2" "啟動/重啟 服務"
    print_entry "3" "停止 服務"
    echo ""

    echo -e " ${B}[ 功能配置 ]${N}"
    print_entry "4" "配置與協議" "${D}(端口/UUID/協議開關)${N}"
    print_entry "5" "證書管理"   "${D}(ACME/證書切換)${N}"
    print_entry "6" "分流工具"   "${D}(WARP/Socks5/IPv6/DNS)${N}"
    print_entry "7" "出口策略"   "${D}(切換 v4/v6 優先級)${N}"
    echo ""

    echo -e " ${B}[ 運維監控 ]${N}"
    print_entry "8" "核心與更新" "${D}(版本管理)${N}"
    print_entry "9" "BBR 加速"   "${D}(系統優化)${N}"
    print_entry "10" "實時日誌"
    print_entry "11" "節點鏈接"  "${G}(查看配置/二維碼)${N}"
    print_entry "12" "${R}卸載 Prism${N}"
    echo -e "${SEP_LINE}"
    
    prompt_ask "請輸入選項" "" menu_choice
    
    case "${menu_choice}" in
        1) action_install ;;
        2) systemctl restart prism; success "服務已重啟"; sleep 1; show_menu ;;
        3) systemctl stop prism; warn "服務已停止"; sleep 1; show_menu ;;
        4) submenu_config ;;
        5) submenu_cert_main ;;
        6) submenu_routing ;;
        7) change_outbound_mode ;;
        8) submenu_core ;;
        9) action_bbr ;;
        10) action_view_logs ;;
        11) show_node_info ;;
        12) action_uninstall ;;
        *)  echo -e "Bye."; exit 0 ;;
    esac
}
