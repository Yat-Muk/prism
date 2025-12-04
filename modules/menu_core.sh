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

if [[ -f "${BASE_DIR}/modules/kernel.sh" ]]; then
    source "${BASE_DIR}/modules/kernel.sh"
else
    echo -e "${R}[Err] 內核模塊丟失${N}"
fi

submenu_core_upgrade() {
    while true; do
        clear; print_banner
        echo -e " ${B}>>> 核心升級/切換${N}"
        echo -e "================================================="
        echo -e " ${Y}正在獲取最新版本信息，請稍候...${N}"
        
        local current_ver="未安裝"
        if [[ -f "${SINGBOX_BIN}" ]]; then
            current_ver=$(${SINGBOX_BIN} version 2>/dev/null | grep "sing-box version" | awk '{print $3}')
        fi
        
        local latest_stable=$(get_remote_version "release")
        local latest_beta=$(get_remote_version "prerelease")
        
        clear; print_banner
        echo -e " ${B}>>> 核心升級/切換${N}"
        echo -e "================================================="
        echo -e "  當前版本: ${C}${current_ver}${N}"
        echo -e "  最新正式: ${G}${latest_stable}${N}"
        echo -e "  最新測試: ${Y}${latest_beta}${N}"
        echo -e "------------------------------------"
        echo -e "  1. 升級/切換最新正式版 ${G}${latest_stable}${N}"
        echo -e "  2. 升級/切換最新測試版 ${Y}${latest_beta}${N}"
        echo -e "  3. 切換指定版本號 ${D}(建議1.10.0以上)${N}"
        echo -e "  0. 返回"
        echo -e "================================================="
        echo -ne " 請輸入選項: "; read -r choice
        
        case "$choice" in
            1) 
                if [[ "$latest_stable" == "N/A" ]]; then
                    error "無法獲取版本信息"
                else
                    install_singbox_core "${latest_stable}" || true
                fi
                read -p "按回車繼續..." 
                ;;
            2) 
                if [[ "$latest_beta" == "N/A" ]]; then
                    error "無法獲取版本信息"
                else
                    install_singbox_core "${latest_beta}" || true
                fi
                read -p "按回車繼續..." 
                ;;
            3) 
                read -p "請輸入版本號 (如 v1.12.0): " input_ver
                if [[ -n "$input_ver" ]]; then
                    install_singbox_core "${input_ver}" || true
                else
                    error "版本號不能為空"
                fi
                read -p "按回車繼續..." 
                ;;
            0) break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
}

check_script_update() {
    clear; print_banner
    echo -e " ${B}>>> 檢查腳本更新${N}"
    echo -e "================================================="
    echo -e " 正在獲取版本信息..."
    
    local ts=$(date +%s)
    local version_url="https://raw.githubusercontent.com/Yat-Muk/prism/main/version?t=${ts}"
    local temp_version_file="/tmp/prism_version_check.txt"
    
    if ! curl -sL --max-time 5 -o "$temp_version_file" "$version_url"; then
        error "無法連接到 GitHub，請檢查網絡。"
        read -p "按回車返回..."
        return
    fi
    
    local remote_ver=$(head -n 1 "$temp_version_file")
    local changelog=$(tail -n +2 "$temp_version_file")
    
    local local_ver="${PROJECT_VERSION}"
    if [[ -f "${WORK_DIR}/version" ]]; then
        local_ver=$(head -n 1 "${WORK_DIR}/version")
    fi
    
    echo -e " 當前版本: ${C}${PROJECT_VERSION}${N}"
    echo -e " 最新版本: ${G}${remote_ver:-未知}${N}"
    echo -e "-------------------------------------------------"
    
    if [[ -z "$remote_ver" ]]; then
        warn "未能獲取到有效的版本號。"
    else
        echo -e " ${Y}更新內容 (Changelog):${N}"
        echo -e "${changelog}"
        echo -e "-------------------------------------------------"
    fi
    
    if [[ "$remote_ver" == "$PROJECT_VERSION" ]]; then
        echo -e " ${G}當前已是最新版本。${N}"
        echo -ne " 是否強制重新安裝? [y/N]: "; read -r force_opt
        if [[ "$force_opt" != "y" && "$force_opt" != "Y" ]]; then return; fi
    else
        echo -ne " ${P}是否立即更新腳本? [y/N]: ${N}"; read -r update_opt
        if [[ "$update_opt" != "y" && "$update_opt" != "Y" ]]; then 
            info "已取消更新。"
            read -p "按回車返回..."
            return
        fi
    fi
    
    perform_script_update
}

perform_script_update() {
    echo ""
    info "正在獲取最新 Prism 安裝器..."
    
    if [ -d "${BASE_DIR}/.git" ]; then
        echo -e "${Y}[Dev] 檢測到 Git 環境，嘗試 git pull...${N}"
        git -C "${BASE_DIR}" pull || true
        success "Git 更新完成，請重新運行"
        exit 0
    else
        local ts=$(date +%s)
        local update_url="https://raw.githubusercontent.com/Yat-Muk/prism/main/install.sh?t=${ts}"
        
        if wget -q -O "${BASE_DIR}/install.sh" "${update_url}"; then
            chmod +x "${BASE_DIR}/install.sh"
            success "引導腳本下載成功，正在執行全量更新..."
            sleep 1
            
            exec bash "${BASE_DIR}/install.sh" update
        else
            error "下載失敗，請檢查網絡連接 (GitHub Raw)"
            read -p "按回車返回主菜單..."; show_menu; return
        fi
    fi
}

submenu_core() {
    while true; do
        clear; print_banner
        echo -e " ${B}>>> 核心與腳本管理${N}"
        echo -e "================================================="
        echo -e "  1. 核心升級/切換 ${D}(可指定版本)${N}"
        echo -e "  2. 腳本升級"
        echo -e "  0. 返回"
        echo -e "================================================="
        echo -ne " 請輸入選項: "; read -r choice
        case "$choice" in
            1) submenu_core_upgrade ;;
            2) check_script_update
               break
               ;;
            0) break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
    show_menu
}
