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

if [[ -f "${BASE_DIR}/modules/menu_config.sh" ]]; then source "${BASE_DIR}/modules/menu_config.sh"; fi
if [[ -f "${BASE_DIR}/modules/kernel.sh" ]]; then source "${BASE_DIR}/modules/kernel.sh"; fi
if [[ -f "${BASE_DIR}/modules/config.sh" ]]; then source "${BASE_DIR}/modules/config.sh"; fi

get_service_status() {
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet prism; then echo -e "${G}● 運行中 (Active)${N}";
        elif systemctl is-failed --quiet prism; then echo -e "${R}● 已崩潰 (Failed)${N}";
        else echo -e "${D}● 已停止 (Stopped)${N}"; fi
    else echo "${Y}未知 (No systemd)${N}"; fi
}

action_view_logs() {
    clear; print_banner
    echo -e " ${B}>>> 實時日誌監控 (Real-time Logs)${N}"
    echo -e " ${D}提示：按 ${Y}Ctrl+C${D} 停止監控並返回菜單${N}"
    echo -e "${SEP}"
    
    if [[ ! -f "${LOG_FILE}" ]]; then
        echo -e " ${Y}暫無日誌文件，正在等待服務產生日誌...${N}"
        touch "${LOG_FILE}"
    fi

    trap 'trap - SIGINT; show_menu; return' SIGINT
    
    tail -f -n 20 "${LOG_FILE}"
    
    trap - SIGINT
}

action_install() {
    clear; print_banner
    echo -e " ${B}>>> Prism 部署流程${N}"
    echo -e "${SEP}"
    
    info "正在檢測系統環境..."
    detect_os
    if [[ -z "${PKG_MANAGER}" ]]; then
        error "不支持的系統發行版"
        read -p "按回車返回..."
        return
    fi
    
    info "正在安裝基礎依賴..."
    install_base_dependencies
    
    check_network_stack
    
    if declare -f install_kernel > /dev/null; then
        install_kernel
    else
        error "內核安裝模塊加載失敗 (kernel.sh missing)"
        return
    fi
    
    if [[ ! -f "${CONFIG_DIR}/secrets.env" ]]; then
        echo -e "\n ${G}[檢測到初次安裝]${N}"
        if declare -f select_protocols_wizard > /dev/null; then
            select_protocols_wizard
        else
            warn "配置嚮導模塊缺失，將使用默認配置"
        fi
    else
        echo -e "\n ${Y}[檢測到已有配置]${N}"
        echo -ne " 是否重新運行配置嚮導 (將覆蓋現有密鑰)? [y/N]: "
        read -r reconf
        if [[ "$reconf" == "y" || "$reconf" == "Y" ]]; then
            rm -f "${CONFIG_DIR}/secrets.env"
            unset $(compgen -v PRISM_)
            if declare -f select_protocols_wizard > /dev/null; then
                select_protocols_wizard
            fi
        fi
    fi
    
    info "正在編譯配置文件..."
    if declare -f build_config > /dev/null; then 
        build_config
    else
        error "配置編譯模塊缺失 (config.sh missing)"
        return
    fi
    
    create_shortcuts
    
    info "正在啟動服務..."
    systemctl enable prism >/dev/null 2>&1
    systemctl restart prism
    
    sleep 1.5
    if systemctl is-active --quiet prism; then 
        success "部署成功！Prism 已在後台運行。"
        echo -e " ${D}提示：輸入 ${C}prism${D} 隨時調出管理菜單${N}"
    else 
        error "服務啟動失敗"
        echo -e " ${Y}正在抓取錯誤日誌:${N}"
        journalctl -u prism -n 5 --no-pager
    fi
    
    read -p "按回車返回主菜單..."
    show_menu
}

action_uninstall() {
    clear; print_banner
    echo -e " ${R}>>> 卸載 Prism (Uninstall)${N}"
    echo -e "${SEP}"
    echo -e " ${Y}危險操作！這將執行以下清理：${N}"
    echo -e "  1. 停止 Prism 服務"
    echo -e "  2. 刪除所有配置文件、證書、日誌 (${WORK_DIR})"
    echo -e "  3. 刪除 Sing-box 核心"
    echo -e "  4. 刪除快捷指令 (prism)"
    echo -e " ${D}(ACME 證書腳本本體將保留)${N}"
    echo -e "${SEP}"
    
    echo -ne " 請輸入 ${R}uninstall${N} 以確認卸載 (輸入其他取消): "
    read -r confirm
    
    if [[ "$confirm" != "uninstall" ]]; then
        info "操作已取消"
        sleep 1
        show_menu
        return
    fi

    echo ""
    run_step "停止服務" "systemctl stop prism >/dev/null 2>&1; systemctl disable prism >/dev/null 2>&1"
    
    run_step "刪除服務文件" "rm -f /etc/systemd/system/prism.service && systemctl daemon-reload"
    
    run_step "刪除快捷指令" "rm -f /usr/bin/prism /usr/bin/vasma"

    echo -ne " ${B}[....]${N} 刪除程序文件..."
    if [[ -d "${WORK_DIR}" ]]; then
        rm -rf "${WORK_DIR}"
    fi
    echo -e "\r ${G}[DONE]${N} 刪除程序文件     "

    echo ""
    echo -e "${G}[ OK ]${N} 卸載完成。感謝使用 Prism。"
    exit 0
}
