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

print_result() {
    local name="$1"
    local color="$2"
    local result="$3"
    local extra="$4"
    
    local width=14
    local padding=$(awk -v str="$name" -v w="$width" 'BEGIN {
        len = length(str); non_ascii = 0;
        for(i=1; i<=len; i++) { if(substr(str,i,1) ~ /[^\x00-\x7F]/) non_ascii++; }
        display_width = len + non_ascii; pad_len = w - display_width;
        if(pad_len < 0) pad_len = 0; printf "%*s", pad_len, "";
    }')
    
    printf " %b%s%b${padding} : %b%s%b %b%s%b\n" "${C}" "${name}" "${N}" "${color}" "${result}" "${N}" "${D}" "${extra}" "${N}"
}

check_chatgpt() {
    local iface=$1
    print_result "ChatGPT" "${D}" "檢測中..." ""
    
    local start_time=$(date +%s%N)
    
    local code_web
    code_web=$(curl "$iface" -s -o /dev/null -w "%{http_code}" --max-time 5 -A "Mozilla/5.0" "https://chatgpt.com")
    
    local code_app
    code_app=$(curl "$iface" -s -o /dev/null -w "%{http_code}" --max-time 5 -A "Mozilla/5.0" "https://ios.chat.openai.com/public-api/mobile/server_status/v1")
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    local time_label="(${duration}ms)"

    tput cuu1; tput el
    
    local web_status="❌"
    local app_status="❌"
    
    if [[ "$code_web" == "200" || "$code_web" == "302" ]]; then web_status="✅"; fi
    
    if [[ "$code_app" == "200" ]]; then app_status="✅"; fi
    
    if [[ "$web_status" == "✅" && "$app_status" == "✅" ]]; then
        print_result "ChatGPT" "${G}" "完整解鎖 (Web + App)" "$time_label"
    elif [[ "$web_status" == "✅" ]]; then
        print_result "ChatGPT" "${Y}" "僅解鎖 Web (App 失敗)" "$time_label"
    elif [[ "$app_status" == "✅" ]]; then
        print_result "ChatGPT" "${Y}" "僅解鎖 App (Web 失敗)" "$time_label"
    else
        if [[ "$code_web" == "403" || "$code_app" == "403" ]]; then
            print_result "ChatGPT" "${R}" "被攔截 (Cloudflare)" "$time_label"
        elif [[ "$code_web" == "429" ]]; then
             print_result "ChatGPT" "${R}" "被限流 (429)" "$time_label"
        else
             print_result "ChatGPT" "${R}" "失敗 ($code_web)" "$time_label"
        fi
    fi
}

check_netflix() {
    local iface=$1
    print_result "Netflix" "${D}" "檢測中..." ""
    local start_time=$(date +%s%N)
    local code_orig=$(curl "$iface" -s -o /dev/null -w "%{http_code}" --max-time 5 -A "Mozilla/5.0" "https://www.netflix.com/title/81215567")
    local code_non_orig=$(curl "$iface" -s -o /dev/null -w "%{http_code}" --max-time 5 -A "Mozilla/5.0" "https://www.netflix.com/title/70143836")
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    local time_label="(${duration}ms)"

    tput cuu1; tput el
    if [[ "$code_orig" == "200" || "$code_orig" == "301" || "$code_orig" == "302" ]]; then
        if [[ "$code_non_orig" == "200" || "$code_non_orig" == "301" || "$code_non_orig" == "302" ]]; then
            print_result "Netflix" "${G}" "完整解鎖 (Full)" "$time_label"
        else
            print_result "Netflix" "${Y}" "僅自製劇 (Originals)" "$time_label"
        fi
    elif [[ "$code_orig" == "403" ]]; then
        print_result "Netflix" "${R}" "IP 被禁 (403)" "$time_label"
    else
        print_result "Netflix" "${R}" "失敗 ($code_orig)" "$time_label"
    fi
}

check_disney() {
    local iface=$1
    print_result "Disney+" "${D}" "檢測中..." ""
    local start_time=$(date +%s%N)
    local output=$(curl "$iface" -I -s --max-time 5 -A "Mozilla/5.0" "https://www.disneyplus.com")
    local code=$(echo "$output" | head -n 1 | awk '{print $2}')
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    local time_label="(${duration}ms)"

    tput cuu1; tput el
    if [[ "$code" == "200" || "$code" == "301" || "$code" == "302" ]]; then
        local location=$(echo "$output" | grep -i "location:" | awk '{print $2}' | tr -d '\r')
        local region="US"
        if [[ -n "$location" ]]; then
            if [[ "$location" =~ /([a-z]{2}-[a-z]{2})/ ]]; then region=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]' | cut -d- -f2);
            elif [[ "$location" =~ \.([a-z]{2})/ ]]; then region=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]'); fi
        fi
        print_result "Disney+" "${G}" "解鎖 (地區: ${region})" "$time_label"
    else
        print_result "Disney+" "${R}" "不可用 ($code)" "$time_label"
    fi
}

check_basic() {
    local iface=$1; local name=$2; local url=$3
    print_result "${name}" "${D}" "檢測中..." ""
    local start_time=$(date +%s%N)
    local code=$(curl "$iface" -s -o /dev/null -w "%{http_code}" --max-time 5 -A "Mozilla/5.0" "$url")
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    local time_label="(${duration}ms)"
    tput cuu1; tput el
    if [[ "$code" == "200" || "$code" == "301" || "$code" == "302" ]]; then print_result "${name}" "${G}" "可用" "$time_label"; else print_result "${name}" "${R}" "失敗 ($code)" "$time_label"; fi
}

tool_ip_check() {
    clear; print_banner
    echo -e " ${B}>>> 服務器 IP 質量檢測 (Native Checker)${N}"
    echo -e " ${D}提示：基於 HTTP 響應頭進行快速診斷。${N}"; echo -e "${SEP}"

    if [[ -n "${IPV4_ADDR}" ]]; then
        echo -e " ${P}[ IPv4 檢測 ]${N}"
        print_result "IP Info" "${D}" "查詢中..."
        local info_4=$(curl -s -4 --max-time 3 ipinfo.io/json)
        local country_4=$(echo "$info_4" | grep '"country":' | cut -d'"' -f4)
        local org_4=$(echo "$info_4" | grep '"org":' | cut -d'"' -f4)
        tput cuu1; tput el
        print_result "本機 IP" "${W}" "${IPV4_ADDR}"
        print_result "地區/ISP" "${Y}" "${country_4} - ${org_4}"; echo -e "${D}----------------------------------------------${N}"
        
        check_basic   "-4" "Google" "https://www.google.com"
        check_basic   "-4" "YouTube" "https://www.youtube.com"
        check_chatgpt "-4"
        check_netflix "-4"
        check_disney  "-4"
    else
        echo -e " ${D}[ IPv4 ] 無公網地址，跳過。${N}"
    fi
    echo -e ""

    if [[ -n "${IPV6_ADDR}" ]]; then
        echo -e " ${P}[ IPv6 檢測 ]${N}"
        print_result "IP Info" "${D}" "查詢中..."
        local info_6=$(curl -s -6 --max-time 3 ipinfo.io/json)
        local country_6=$(echo "$info_6" | grep '"country":' | cut -d'"' -f4)
        local org_6=$(echo "$info_6" | grep '"org":' | cut -d'"' -f4)
        tput cuu1; tput el
        print_result "本機 IP" "${W}" "${IPV6_ADDR}"
        print_result "地區/ISP" "${Y}" "${country_6} - ${org_6}"; echo -e "${D}----------------------------------------------${N}"

        check_basic   "-6" "Google" "https://www.google.com"
        check_basic   "-6" "YouTube" "https://www.youtube.com"
        check_chatgpt "-6"
        check_netflix "-6"
        check_disney  "-6"
    else
        echo -e " ${D}[ IPv6 ] 無公網地址，跳過。${N}"
    fi

    echo -e "${SEP}"; read -p " 按回車返回..."
}

tool_backup() {
    clear; print_banner
    echo -e " ${B}>>> 配置備份 (Backup)${N}"; echo -e " ${D}將備份：secrets.env (密鑰配置) + cert (證書)${N}"; echo -e "${SEP}"
    local backup_file="/root/prism_backup_$(date +%Y%m%d).tar.gz"
    mkdir -p "${WORK_DIR}/cert" "${WORK_DIR}/cert_acme"
    if tar -czf "$backup_file" -C "${WORK_DIR}" conf/secrets.env cert cert_acme >/dev/null 2>&1; then
        success "備份成功！"; echo -e " 備份文件路徑: ${G}${backup_file}${N}"; echo -e " ${Y}請下載此文件到本地妥善保存。${N}"
        echo -e " 恢復方法: 上傳至新服務器，解壓覆蓋 ${WORK_DIR} 對應目錄，然後重裝 Prism。"
    else error "備份失敗，請檢查磁盤空間或權限。"; fi
    read -p " 按回車返回..."
}

tool_cleanup() {
    echo ""; info "正在清理系統垃圾..."
    echo "" > "${LOG_FILE}"; echo "" > "${WORK_DIR}/box.log"
    rm -f "${WORK_DIR}/cache.db"; rm -f "${WORK_DIR}/temp_client.json"; rm -f "${TEMP_DIR}"/* 2>/dev/null; rm -f "/tmp/prism_version_check.txt"
    success "清理完成 (Logs flushed, Cache removed)"; sleep 1.5
}

submenu_tool() {
    while true; do
        clear; print_banner
        echo -e " ${B}>>> 實用工具箱 (Toolbox)${N}"; echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}流媒體/IP質量檢測${N}  ${D}(原生檢測/無外部依賴)${N}"
        echo -e "  ${P}2.${N} ${W}配置備份${N}           ${D}(導出密鑰與證書)${N}"
        echo -e "  ${P}3.${N} ${W}系統清理${N}           ${D}(清空日誌/緩存)${N}"
        echo -e "${SEP}"; echo -e "  ${P}0.${N} 返回主菜單"; echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        case "$choice" in 1) tool_ip_check ;; 2) tool_backup ;; 3) tool_cleanup ;; 0) break ;; *) error "無效輸入"; sleep 1 ;; esac
    done
    show_menu
}
