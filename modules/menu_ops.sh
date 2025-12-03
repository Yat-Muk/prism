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

if [[ -f "${BASE_DIR}/modules/menu_config.sh" ]]; then
    source "${BASE_DIR}/modules/menu_config.sh"
fi

get_service_status() {
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet prism; then echo -e "${G}● 運行中 (Active)${N}";
        elif systemctl is-failed --quiet prism; then echo -e "${R}● 已崩潰 (Failed)${N}";
        else echo -e "${D}● 已停止 (Stopped)${N}"; fi
    else echo "未知"; fi
}

action_view_logs() {
    clear; print_banner
    echo -e " ${B}>>> 實時日誌監控 (Real-time Logs)${N}"
    echo -e " ${Y}[提示] 日誌正在輸出中，請按 【回車鍵 (Enter)】 停止並返回主菜單...${N}"
    echo -e "${SEP}"
    
    if [[ ! -f "${LOG_FILE}" ]]; then
        echo -e "${R}[Err] 日誌文件不存在 (${LOG_FILE})${N}"
        read -p "按回車返回..."
        show_menu
        return
    fi

    tail -f -n 20 "${LOG_FILE}" &
    local tail_pid=$!
    
    tput civis
    read -r _
    tput cnorm
    
    kill "$tail_pid" >/dev/null 2>&1 || true
    wait "$tail_pid" 2>/dev/null || true
    
    show_menu
}

action_install() {
    clear; print_banner
    info "啟動 Prism 安裝流程..."
    
    detect_os
    install_base_dependencies
    check_network_stack
    
    if [[ -f "${BASE_DIR}/modules/kernel.sh" ]]; then 
        source "${BASE_DIR}/modules/kernel.sh"
        install_kernel
    else
        error "找不到 kernel 模塊"
        return
    fi
    
    if [[ ! -f "${CONFIG_DIR}/secrets.env" ]]; then
        info "檢測到首次安裝，進入配置嚮導..."
        if declare -f select_protocols_wizard > /dev/null; then
            select_protocols_wizard
        else
            warn "嚮導模塊未加載，使用默認配置..."
        fi
    elif [[ -f "${CONFIG_DIR}/secrets.env" ]]; then
        echo ""
        echo -e "${Y}[提示] 檢測到系統中已存在 Prism 配置文件。${N}"
        echo -ne "是否重新選擇協議並重置配置? (這將覆蓋現有密鑰) [y/N]: "
        read -r reconf_choice
        if [[ "$reconf_choice" == "y" || "$reconf_choice" == "Y" ]]; then
            info "正在進入配置嚮導..."
            rm -f "${CONFIG_DIR}/secrets.env"
            unset $(compgen -v PRISM_)
            if declare -f select_protocols_wizard > /dev/null; then select_protocols_wizard; fi
        fi
    fi
    
    info ">>> 正在構建配置文件"
    if [[ -f "${BASE_DIR}/modules/config.sh" ]]; then 
        source "${BASE_DIR}/modules/config.sh"
        build_config
        if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi
    else
        error "找不到 config 模塊"
        return
    fi
    
    create_shortcuts
    
    info "正在啟動服務..."
    systemctl enable prism >/dev/null 2>&1
    systemctl restart prism
    sleep 1
    
    if systemctl is-active --quiet prism; then 
        success "部署成功！"
    else 
        error "啟動失敗，請檢查日誌"
        journalctl -u prism -n 3 --no-pager
    fi
    
    read -p "按回車返回..."
    show_menu
}

action_uninstall() {
    clear; print_banner
    echo -e "${R}!!! 危險操作 (DANGER) !!!${N}"
    echo -e "此操作將執行以下清理："
    echo -e " 1. 停止並刪除 Prism 服務 (Systemd)"
    echo -e " 2. 刪除所有配置、日誌、證書及核心文件 (${WORK_DIR})"
    echo -e " 3. 刪除全局快捷指令 (prism / vasma)"
    echo -e " ${D}------------------------------------${N}"
    echo -e " ${Y}注意：不會卸載 acme.sh 本體 (保留在 ~/.acme.sh)${N}"
    echo -e "${SEP}"
    echo -ne " ${Y}是否確認卸載？[y/N]: ${N}"; read -r confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "操作已取消"
        sleep 1
        show_menu
        return
    fi

    info "正在停止服務..."
    systemctl stop prism >/dev/null 2>&1
    systemctl disable prism >/dev/null 2>&1
    rm -f /etc/systemd/system/prism.service
    systemctl daemon-reload

    info "正在刪除文件..."
    rm -f /usr/bin/prism /usr/bin/vasma
    
    if [[ -d "${WORK_DIR}" ]]; then
        rm -rf "${WORK_DIR}"
    fi

    echo ""
    echo -e "${G}[ OK ]${N} Prism 已徹底卸載。江湖路遠，有緣再見！"
    exit 0
}