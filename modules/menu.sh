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

if [[ -f "${BASE_DIR}/modules/menu_routing.sh" ]]; then source "${BASE_DIR}/modules/menu_routing.sh"; else submenu_routing() { echo "Dev..."; sleep 1; show_menu; }; fi
if [[ -f "${BASE_DIR}/modules/menu_core.sh" ]]; then source "${BASE_DIR}/modules/menu_core.sh"; else submenu_core() { echo "Dev..."; sleep 1; show_menu; }; fi
if [[ -f "${BASE_DIR}/modules/menu_bbr.sh" ]]; then source "${BASE_DIR}/modules/menu_bbr.sh"; else action_bbr() { echo "Dev..."; sleep 1; show_menu; }; fi

if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi

get_script_update_info() {
    local remote_ver=$(curl -sL --max-time 2 "https://raw.githubusercontent.com/Yat-Muk/prism/main/version" | head -n 1)
    if [[ -n "$remote_ver" && "$remote_ver" != "$PROJECT_VERSION" ]]; then
        echo "${Y}(發現新版: ${remote_ver})${N}"
    else
        echo ""
    fi
}

get_core_version_info() {
    local local_ver="未安裝"
    local update_hint=""
    if [[ -f "${SINGBOX_BIN}" ]]; then
        local_ver=$(${SINGBOX_BIN} version 2>/dev/null | grep "sing-box version" | awk '{print $3}')
        
        local remote_ver=$(curl -sL --max-time 2 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        
        if [[ -n "$remote_ver" ]]; then
             local l_v="${local_ver#v}"; local r_v="${remote_ver#v}"
             if [[ "$l_v" != "$r_v" ]]; then update_hint="${Y}(檢測到新版本 ${remote_ver})${N}"; fi
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

show_menu() {
    clear
    if [[ -z "${NETWORK_STACK}" ]]; then check_network_stack; fi
    if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi
    
    local status=$(get_service_status)

    local script_update_hint=$(get_script_update_info)
    local core_info=$(get_core_version_info)
    
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

    local local_script_ver="未知"
    if [[ -f "${WORK_DIR}/version" ]]; then
        local_script_ver=$(head -n 1 "${WORK_DIR}/version")
    else
        local_script_ver="${PROJECT_VERSION}"
    fi

    print_banner
    echo -e " 作者：${PROJECT_AUTHOR}           腳本版本：${PROJECT_VERSION} ${script_update_hint}"
    echo -e " 項目地址：${B}${PROJECT_URL}${N}"
    echo -e "${SEP}"
    
    echo -e " 系統: ${N}${OS_RELEASE:-Unknown} ${OS_VERSION}${N}    內核:${N}${kernel_ver:-Unknown}${N}    BBR算法:${G}${bbr_status:-Unknown}${N}"
    echo -e " 核心版本: ${core_info}"
    echo -e " 運行狀態: ${status}"
    echo -e " 出口優先級: ${Y}$(get_outbound_mode_text)${N}"
    echo -e " IPv4地址: ${v4_disp}"
    echo -e " IPv6地址: ${v6_disp}"
    echo -e "${SEP}"
    
    echo -e "  ${P}1.${N} ${install_color}安裝 / 更新 Prism${N} (${install_text})"
    echo -e "  ${P}2.${N} ${W}啟動 / 重啟 服務${N}"
    echo -e "  ${P}3.${N} ${W}停止 服務${N}"
    echo -e "${D}  ------------------------------------${N}"
    echo -e "  ${P}4.${N} ${W}配置與協議管理${N}    ${D}(協議選擇/配置重置/Reality偽裝/UUID/端口)${N}"
    echo -e "  ${P}5.${N} ${W}證書管理${N}          ${D}(ACME證書申請/證書切換)${N}"
    echo -e "  ${P}6.${N} ${W}切換 出口優先級${N}   ${D}(IPv4/IPv6)${N}"
    echo -e "  ${P}7.${N} ${W}分流工具${N}          ${D}(WARP/Socks5/IPv6/DNS/SNI反向代理)${N}"
    echo -e "  ${P}8.${N} ${W}核心與腳本管理${N}    ${D}(可指定核心版本/腳本更新)${N}"
    echo -e "  ${P}9.${N} ${W}BBR 加速${N}          ${D}(原版BBR/XanMod-BBRv3)${N}"
    echo -e "${D}  ------------------------------------${N}"
    echo -e "  ${P}10.${N}${G}查看 實時日誌${N}"
    echo -e "  ${P}11.${N}${G}查看 所有節點鏈接${N} ${D}(含二維碼)${N}"
    echo -e "${D}  ------------------------------------${N}"
    echo -e "  ${P}12.${N}${R}卸載 Prism${N}        ${D}(刪除程序和配置)${N}"
    echo -e "  ${P}0.${N} 退出"
    echo -e "${SEP}"
    
    echo -ne " 請輸入選項 [0-12]: "
    read -r choice
    case "${choice}" in
        1) action_install ;;
        2) systemctl restart prism; success "服務已重啟"; sleep 1; show_menu ;;
        3) systemctl stop prism; warn "服務已停止"; sleep 1; show_menu ;;
        4) submenu_config ;;
        5) submenu_cert_main ;;
        6) change_outbound_mode ;;
        7) submenu_routing ;;
        8) submenu_core ;;
        9) action_bbr ;;
        10) action_view_logs ;;
        11) show_node_info ;;
        12) action_uninstall ;;
        0) echo -e "Bye."; exit 0 ;;
        *) error "無效輸入"; sleep 1; show_menu ;;
    esac
}
