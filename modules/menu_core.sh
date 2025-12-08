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
    echo -e "${R}[Err] 內核模塊丟失 (Kernel module missing)${N}"
fi

_render_core_menu() {
    local cur=$1
    local stable=$2
    local beta=$3
    
    clear; print_banner
    echo -e " ${B}>>> 核心管理 (Core Management)${N}"
    echo -e "${SEP}"
    echo -e " 當前版本: ${cur}"
    echo -e " 最新正式: ${stable}"
    echo -e " 最新預覽: ${beta}"
    echo -e "${SEP}"
    echo -e "  ${P}1.${N} ${W}安裝/更新 正式版${N}"
    echo -e "  ${P}2.${N} ${W}安裝/更新 預覽版 (Pre-release)${N}"
    echo -e "  ${P}3.${N} ${W}安裝 指定版本${N}"
    echo -e "${SEP}"
    echo -e "  ${P}0.${N} 返回上級菜單"
    echo -e "${SEP}"
}

submenu_core_upgrade() {
    local local_ver_display="${D}檢測中...${N}"
    local remote_stable_display="${D}獲取中...${N}"
    local remote_beta_display="${D}獲取中...${N}"
    
    local raw_stable="N/A"
    local raw_beta="N/A"

    if [[ -f "${CACHE_FILE}" ]]; then source "${CACHE_FILE}"; raw_stable="${REMOTE_CORE_VER:-N/A}"; fi
    
    if [[ -f "${SINGBOX_BIN}" ]]; then local v=$(${SINGBOX_BIN} version 2>/dev/null | grep "sing-box version" | awk '{print $3}'); local_ver_display="${C}${v}${N}"; else local_ver_display="${D}未安裝${N}"; fi
    
    if [[ "$raw_stable" == "N/A" ]]; then raw_stable=$(get_remote_version "release"); fi
    raw_beta=$(get_remote_version "prerelease")

    if [[ "$raw_stable" != "N/A" ]]; then remote_stable_display="${G}${raw_stable}${N}"; else remote_stable_display="${R}失敗${N}"; fi
    if [[ "$raw_beta" != "N/A" ]]; then remote_beta_display="${Y}${raw_beta}${N}"; else remote_beta_display="${R}失敗${N}"; fi

    while true; do
        _render_core_menu "$local_ver_display" "$remote_stable_display" "$remote_beta_display"
        
        echo -ne " 請輸入選項: "; read -r choice
        
        case "$choice" in
            1) 
                if [[ "$raw_stable" == "N/A" ]]; then error "無法獲取版本信息"; sleep 1; continue; fi
                install_singbox_core "${raw_stable}" || true
                
                local_ver_display="${C}${raw_stable}${N}"
                read -p " 按回車繼續..." 
                ;;
            2) 
                if [[ "$raw_beta" == "N/A" ]]; then error "無法獲取版本信息"; sleep 1; continue; fi
                install_singbox_core "${raw_beta}" || true
                
                local_ver_display="${C}${raw_beta}${N}"
                read -p " 按回車繼續..." 
                ;;
            3) 
                echo ""
                read -p " 請輸入版本號 (如 v1.12.0，輸入 0 取消): " input_ver
                if [[ "$input_ver" == "0" ]]; then continue; fi
                if [[ -n "$input_ver" ]]; then
                    install_singbox_core "${input_ver}" || true
                    local_ver_display="${C}${input_ver}${N}"
                else
                    warn "輸入為空"
                fi
                read -p " 按回車繼續..." 
                ;;
            0) break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
}

check_script_update() {
    clear; print_banner
    echo -e " ${B}>>> 腳本更新 (Script Update)${N}"
    echo -e "${SEP}"
    echo -e " 獲取最新版本信息..."
    
    local ts=$(date +%s)
    local version_url="https://raw.githubusercontent.com/Yat-Muk/prism/main/version?t=${ts}"
    local temp_version_file="/tmp/prism_version_check.txt"
    
    if ! curl -sL --max-time 5 -o "$temp_version_file" "$version_url"; then
        error "無法連接 GitHub，請檢查網絡。"
        read -p "按回車返回..."
        return
    fi

    local remote_ver=$(sed -n '1p' "$temp_version_file")
    local changelog=$(sed -n '2,$p' "$temp_version_file")
    
    local local_ver="${PROJECT_VERSION}"
    if [[ -f "${WORK_DIR}/version" ]]; then
        local_ver=$(head -n 1 "${WORK_DIR}/version")
    fi
    
    echo -e " 當前版本: ${C}${local_ver}${N}"
    echo -e " 最新版本: ${G}${remote_ver:-未知}${N}"
    echo -e "${SEP}"
    
    if [[ -n "$changelog" ]]; then
        echo -e " ${Y}更新日誌 (Changelog):${N}"
        echo -e "${changelog}"
        echo -e "${SEP}"
    fi
    
    local prompt_msg="是否立即更新腳本? [y/N]"
    if [[ "$remote_ver" == "$local_ver" ]]; then echo -e " ${G}當前已是最新版本。${N}"; prompt_msg="是否強制更新腳本? [y/N]"; fi
    
    echo -ne " ${prompt_msg}: "; read -r update_opt
    if [[ "$update_opt" != "y" && "$update_opt" != "Y" ]]; then return; fi
    perform_script_update
}

perform_script_update() {
    echo ""
    info "正在拉取最新安裝腳本..."
    
    local ts=$(date +%s)
    local update_url="https://raw.githubusercontent.com/Yat-Muk/prism/main/install.sh?t=${ts}"
        
    if wget -q -O "${BASE_DIR}/install.sh" "${update_url}"; then 
        chmod +x "${BASE_DIR}/install.sh"
        success "更新成功，正在重載..."
        
        if declare -f force_check_update > /dev/null; then
             ( force_check_update >/dev/null 2>&1 ) &
        fi
        
        sleep 1
        exec bash "${BASE_DIR}/install.sh" update
    else 
        error "下載失敗"
        read -p "按回車返回..."
        return
    fi
}

submenu_core() {
    while true; do
        clear; print_banner
        echo -e " ${B}>>> 核心與腳本管理${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}核心版本管理${N}      ${D}(升級/降級 Sing-box)${N}"
        echo -e "  ${P}2.${N} ${W}腳本更新${N}          ${D}(檢查 Prism 更新)${N}"
        echo -e "  ${P}3.${N} ${Y}檢查更新${N}          ${D}(刷新遠程版本緩存)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        case "$choice" in
            1) submenu_core_upgrade ;;
            2) check_script_update; break ;; 
            3) 
                if declare -f force_check_update > /dev/null; then 
                    force_check_update
                else 
                    error "函數未定義 (請重啟腳本)"
                fi
                ;;
            0) break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
    show_menu
}
