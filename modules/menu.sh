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

if [[ -f "${BASE_DIR}/modules/menu_routing.sh" ]]; then source "${BASE_DIR}/modules/menu_routing.sh"; else submenu_routing() { warn "模塊缺失"; sleep 1; show_menu; }; fi
if [[ -f "${BASE_DIR}/modules/menu_core.sh" ]]; then source "${BASE_DIR}/modules/menu_core.sh"; else submenu_core() { warn "模塊缺失"; sleep 1; show_menu; }; fi
if [[ -f "${BASE_DIR}/modules/menu_bbr.sh" ]]; then source "${BASE_DIR}/modules/menu_bbr.sh"; else action_bbr() { warn "模塊缺失"; sleep 1; show_menu; }; fi
if [[ -f "${BASE_DIR}/modules/menu_tool.sh" ]]; then source "${BASE_DIR}/modules/menu_tool.sh"; else submenu_tool() { warn "模塊缺失"; sleep 1; show_menu; }; fi

if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi

CACHE_FILE="/tmp/prism_ver_cache"
CACHE_TTL=3600

task_check_update_async() {
    if pgrep -f "prism_update_checker" > /dev/null; then return; fi 
    (
        local r_script="N/A"
        local r_core="N/A"
    
        r_script=$(curl -sL --max-time 10 "https://raw.githubusercontent.com/Yat-Muk/prism/main/version" | head -n 1)
        r_core=$(curl -sL --max-time 10 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        
        cat > "${CACHE_FILE}.tmp" <<EOF
REMOTE_SCRIPT_VER="${r_script}"
REMOTE_CORE_VER="${r_core}"
LAST_CHECK=$(date +%s)
EOF
        mv "${CACHE_FILE}.tmp" "${CACHE_FILE}"
    ) & >/dev/null 2>&1
}

trigger_update_check() {
    local now=$(date +%s)
    local last_check=0
    
    if [[ -f "${CACHE_FILE}" ]]; then
        source "${CACHE_FILE}"
        last_check=${LAST_CHECK:-0}
    fi
    
    if (( now - last_check > CACHE_TTL )); then
        task_check_update_async
    fi
}

get_script_update_hint() {
    if [[ -f "${CACHE_FILE}" ]]; then
        source "${CACHE_FILE}"
        if [[ -n "${REMOTE_SCRIPT_VER}" && "${REMOTE_SCRIPT_VER}" != "N/A" && "${REMOTE_SCRIPT_VER}" != "${PROJECT_VERSION}" ]]; then
            echo "${Y}(新版: ${REMOTE_SCRIPT_VER})${N}"
            return
        fi
    fi
    echo ""
}

get_core_version_display() {
    local local_ver="未安裝"
    local update_hint=""
    
    if [[ -f "${SINGBOX_BIN}" ]]; then
        local_ver=$(${SINGBOX_BIN} version 2>/dev/null | grep "sing-box version" | awk '{print $3}')
        
        if [[ -f "${CACHE_FILE}" ]]; then
            source "${CACHE_FILE}"
            if [[ -n "${REMOTE_CORE_VER}" && "${REMOTE_CORE_VER}" != "N/A" ]]; then
                local l_v="${local_ver#v}"
                local r_v="${REMOTE_CORE_VER#v}"
                if [[ "$l_v" != "$r_v" ]]; then 
                    update_hint="${Y}(新版 ${REMOTE_CORE_VER})${N}"
                fi
            fi
        fi
    fi
    echo "${C}sing-box v${local_ver}${N} ${update_hint}"
}

get_outbound_mode_text() {
    case "${PRISM_OUTBOUND_MODE:-prefer_ipv4}" in
        prefer_ipv4) echo "IPv4 優先" ;; prefer_ipv6) echo "IPv6 優先" ;;
        ipv4_only) echo "僅 IPv4" ;; ipv6_only) echo "僅 IPv6" ;; *) echo "默認" ;;
    esac
}

force_check_update() {
    clear; print_banner
    echo -e " ${B}>>> 正在檢查更新...${N}"
    rm -f "${CACHE_FILE}"
    
    local r_script=$(curl -sL --max-time 10 "https://raw.githubusercontent.com/Yat-Muk/prism/main/version" | head -n 1)
    local r_core=$(curl -sL --max-time 10 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    cat > "${CACHE_FILE}" <<EOF
REMOTE_SCRIPT_VER="${r_script}"
REMOTE_CORE_VER="${r_core}"
LAST_CHECK=$(date +%s)
EOF
    
    success "檢查完成"
    sleep 1
}

show_menu() {
    clear
    trigger_update_check

    if [[ -z "${OS_RELEASE}" ]]; then detect_os; fi
    if [[ -z "${NETWORK_STACK}" ]]; then check_network_stack; fi
    if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi
    
    local status=$(get_service_status)
    local script_update_hint=$(get_script_update_hint)
    local core_info=$(get_core_version_display)
    
    local kernel_ver=$(uname -r 2>/dev/null | cut -d- -f1)
    local bbr_status=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    
    local v4_disp="${IPV4_ADDR:-${D}無${N}}"
    local v6_disp="${IPV6_ADDR:-${D}無${N}}"
    
    if [[ "$v4_disp" != "${D}無${N}" ]]; then v4_disp="${W}${v4_disp}${N}"; fi
    if [[ "$v6_disp" != "${D}無${N}" ]]; then v6_disp="${W}${v6_disp}${N}"; fi
    
    local install_text=""
    local install_color=""
    if [[ -f "${SINGBOX_BIN}" ]]; then 
        install_text="${R}重新部署${N}"
        install_color="${W}"
    else 
        install_text="${R}部署服務${N}"
        install_color="${R}"
    fi

    print_banner
    echo -e " 作者：${PROJECT_AUTHOR}           腳本版本：${PROJECT_VERSION} ${script_update_hint}"
    echo -e " 項目地址：${B}${PROJECT_URL}${N}"
    echo -e "${SEP}"
    
    echo -e " 系統: ${N}${OS_RELEASE:-Unknown} ${OS_VERSION}${N}    內核:${N}${kernel_ver:-Unknown}${N}    BBR算法:${G}${bbr_status:-Unknown}${N}"
    echo -e " 核心版本: ${core_info}"
    echo -e " 運行狀態: ${status}"
    echo -e " 出口策略: ${Y}$(get_outbound_mode_text)${N}"
    echo -e " IPv4地址: ${v4_disp}"
    echo -e " IPv6地址: ${v6_disp}"
    echo -e "${SEP}"
    
    echo -e "  ${P}1.${N} ${install_color}安裝部署 Prism${N} (${install_text})"
    echo -e "  ${P}2.${N} ${W}啟動 / 重啟 服務${N}"
    echo -e "  ${P}3.${N} ${W}停止 服務${N}"
    echo -e "${D}  ------------------------------------${N}"
    echo -e "  ${P}4.${N} ${W}配置與協議${N}     ${D}(協議開關/配置重置/SNI域名/UUID/端口)${N}"
    echo -e "  ${P}5.${N} ${W}證書管理${N}       ${D}(ACME證書申請/證書切換)${N}"
    echo -e "  ${P}6.${N} ${W}出口策略${N}       ${D}(切換 IPv4/IPv6 優先級)${N}"
    echo -e "  ${P}7.${N} ${W}分流工具${N}       ${D}(WARP/Socks5/IPv6/DNS/SNI反向代理)${N}"
    echo -e "${D}  ------------------------------------${N}"
    echo -e "  ${P}8.${N} ${W}核心與更新${N}     ${D}(核心/腳本版本管理)${N}"
    echo -e "  ${P}9.${N} ${W}實用工具${N}       ${D}(BBR/Swap/SSH防護/IP檢測/備份/清理)${N}"
    echo -e "  ${P}10.${N}${W}查看 實時日誌${N}"
    echo -e "  ${P}11.${N}${G}查看 節點信息${N}  ${D}(鏈接/二維碼/客戶端JSON)${N}"
    echo -e "${D}  ------------------------------------${N}"
    echo -e "  ${P}12.${N}${R}卸載 Prism${N}     ${D}(刪除程序和配置)${N}"
    echo -e "  ${P}0.${N} 退出"
    echo -e "${SEP}"
    
    echo -ne " 請輸入選項 [0-12]: "
    read -r choice
    case "${choice}" in
        1) action_install ;;
        2) systemctl restart sing-box; 
           if declare -f apply_firewall_rules >/dev/null; then apply_firewall_rules; fi; 
           success "服務已重啟"; sleep 1.5; show_menu ;;
        3) systemctl stop sing-box; 
           if declare -f flush_firewall_rules >/dev/null; then 
               flush_firewall_rules; 
               info "防火牆規則已清理"
           fi; 
           warn "服務已停止"; sleep 1.5; show_menu ;;
        4) submenu_config ;;
        5) submenu_cert_main ;;
        6) change_outbound_mode ;;
        7) submenu_routing ;;
        8) submenu_core ;;
        9) submenu_tool ;;
        10) action_view_logs ;;
        11) show_node_info ;;
        12) action_uninstall ;;
        0) echo -e "Bye."; exit 0 ;;
        *) error "無效輸入"; sleep 1; show_menu ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_menu
fi