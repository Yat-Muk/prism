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

if [[ -f "${BASE_DIR}/modules/menu_config.sh" ]]; then source "${BASE_DIR}/modules/menu_config.sh"; fi
if [[ -f "${BASE_DIR}/modules/kernel.sh" ]]; then source "${BASE_DIR}/modules/kernel.sh"; fi
if [[ -f "${BASE_DIR}/modules/config.sh" ]]; then source "${BASE_DIR}/modules/config.sh"; fi

get_service_status() {
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet sing-box; then echo -e "${G}● 運行中 (Active)${N}";
        elif systemctl is-failed --quiet sing-box; then echo -e "${R}● 已崩潰 (Failed)${N}";
        else echo -e "${D}● 已停止 (Stopped)${N}"; fi
    else echo "${Y}未知 (No systemd)${N}"; fi
}

action_view_logs() {
    clear; print_banner
    echo -e " ${B}>>> 實時日誌監控 (Real-time Logs)${N}"
    echo -e " ${D}提示：按 ${Y}Ctrl+C${D} 停止監控並返回菜單${N}"
    echo -e "${SEP}"
    
    local traffic_log="${WORK_DIR}/box.log"
    local script_log="${LOG_FILE}"
    
    if [[ ! -f "${traffic_log}" ]]; then touch "${traffic_log}"; chmod 600 "${traffic_log}"; fi
    if [[ ! -f "${script_log}" ]]; then touch "${script_log}"; fi

    echo -e " 正在監控: ${G}核心流量${N} & ${C}系統操作${N}"
    echo -e "${SEP}"

    trap 'trap - SIGINT; show_menu; return' SIGINT
    tail -f -n 15 "${script_log}" "${traffic_log}"
    trap - SIGINT
}

action_install() {
    clear; print_banner
    echo -e " ${B}>>> Prism 部署流程${N}"
    echo -e "${SEP}"
    
    info "正在檢測系統環境..."
    detect_os
    if [[ -z "${PKG_MANAGER}" ]]; then error "不支持的系統發行版"; read -p "..."; return; fi
    
    info "正在安裝基礎依賴..."
    install_base_dependencies
    if ! command -v jq &> /dev/null; then error "關鍵依賴 'jq' 安裝失敗"; return; fi
    
    check_network_stack
    
    if [[ -f "${BASE_DIR}/modules/kernel.sh" ]]; then source "${BASE_DIR}/modules/kernel.sh"; fi
    
    if declare -f install_kernel > /dev/null; then
        if ! install_kernel; then error "核心安裝失敗"; return; fi
    else error "內核安裝模塊丟失"; return; fi
    
    if [[ ! -f "${CONFIG_DIR}/secrets.env" ]]; then
        echo -e "\n ${G}[檢測到初次安裝]${N}"
        if declare -f select_protocols_wizard > /dev/null; then select_protocols_wizard; else warn "配置嚮導模塊缺失"; fi
    else
        echo -e "\n ${Y}[檢測到已有配置]${N}"
        echo -ne " 是否重新運行配置嚮導 (將覆蓋現有密鑰)? [y/N]: "; read -r reconf
        if [[ "$reconf" == "y" || "$reconf" == "Y" ]]; then rm -f "${CONFIG_DIR}/secrets.env"; unset $(compgen -v PRISM_); if declare -f select_protocols_wizard > /dev/null; then select_protocols_wizard; fi; fi
    fi
    
    info "正在編譯配置文件..."
    if [[ -f "${BASE_DIR}/modules/config.sh" ]]; then source "${BASE_DIR}/modules/config.sh"; fi
    
    if declare -f build_config > /dev/null; then 
        if ! build_config; then error "配置文件編譯失敗"; read -p "..."; return; fi
    else error "配置編譯模塊缺失"; return; fi
    
    create_shortcuts
    
    info "正在啟動服務..."
    systemctl enable sing-box >/dev/null 2>&1
    systemctl restart sing-box
    
    if declare -f apply_firewall_rules > /dev/null; then apply_firewall_rules; else warn "無法應用防火牆規則"; fi

    sleep 2
    if systemctl is-active --quiet sing-box; then 
        success "部署成功！Prism 已在後台運行。"
        echo -e " ${D}提示：輸入 ${C}prism${D} 隨時調出管理菜單${N}"
    else 
        error "服務啟動失敗"
        echo -e " ${Y}正在抓取錯誤日誌:${N}"
        journalctl -u sing-box -n 10 --no-pager
    fi
    
    read -p "按回車返回主菜單..."
    show_menu
}

action_uninstall() {
    clear; print_banner
    echo -e " ${R}>>> 卸載 Prism (Uninstall)${N}"
    echo -e "${SEP}"
    echo -e " ${Y}危險操作！這將執行以下清理：${N}"
    echo -e "  1. 停止 Sing-box 服務"
    echo -e "  2. 刪除所有配置文件、證書、日誌 (${WORK_DIR})"
    echo -e "  3. 刪除 Sing-box 核心"
    echo -e "  4. 刪除快捷指令 (prism)"
    echo -e " ${D}(ACME 證書腳本本體將保留)${N}"
    echo -e "${SEP}"
    
    echo -ne " 請輸入 ${R}uninstall${N} 以確認卸載 (輸入其他取消): "; read -r confirm
    if [[ "$confirm" != "uninstall" ]]; then info "操作已取消"; sleep 1; show_menu; return; fi

    echo ""
    run_step "停止服務" "systemctl stop sing-box >/dev/null 2>&1; systemctl disable sing-box >/dev/null 2>&1"
    run_step "刪除服務文件" "rm -f /etc/systemd/system/sing-box.service && systemctl daemon-reload"
    run_step "刪除快捷指令" "rm -f /usr/bin/prism /usr/bin/vasma"
    
    if declare -f flush_firewall_rules > /dev/null; then
        flush_firewall_rules
    else
        iptables -t nat -F PRISM_HOPPING 2>/dev/null
        iptables -F PRISM_HOPPING 2>/dev/null
        iptables -t nat -X PRISM_HOPPING 2>/dev/null
        iptables -X PRISM_HOPPING 2>/dev/null
    fi

    if [[ -f "${SINGBOX_BIN}" ]]; then
        rm -f "${SINGBOX_BIN}"
    fi
    
    echo -ne "${B}[....]${N} 刪除程序文件..."
    if [[ -d "${WORK_DIR}" ]]; then rm -rf "${WORK_DIR}"; fi
    echo -e "\r${G}[DONE]${N} 刪除程序文件     "

    echo ""
    echo -e "${G}[ OK ]${N} 卸載完成。感謝使用 Prism。"
    exit 0
}