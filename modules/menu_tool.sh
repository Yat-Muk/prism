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

if [[ -f "${BASE_DIR}/modules/menu_bbr.sh" ]]; then source "${BASE_DIR}/modules/menu_bbr.sh"; fi

print_row() {
    printf " %b%-14s%b : %b%b%b\n" "${C}" "$1" "${N}" "$2" "$3" "${N}"
}

check_target() {
    local iface=$1; local name=$2; local url=$3
    local ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    print_row "${name}" "${D}" "檢測中..."
    
    local start_time=$(date +%s%N)
    local code=$(curl "$iface" -sL -o /dev/null -w "%{http_code}" --max-time 5 -A "$ua" "$url")
    local end_time=$(date +%s%N); local duration=$(( (end_time - start_time) / 1000000 )); local time_label="(${duration}ms)"
    
    local result_color="${R}"; local result_text="失敗 (${code})"

    if [[ "$code" == "000" ]]; then
        tput cuu1; tput el; print_row "${name}" "${R}" "連接超時 (Network Error)"
        return
    fi

    case "$name" in
        "Google"|"YouTube") 
            if [[ "$code" =~ ^(200|301|302)$ ]]; then result_color="${G}"; result_text="可用"; fi 
            ;;
        "ChatGPT") 
            if [[ "$code" =~ ^(200|302)$ ]]; then result_color="${G}"; result_text="允許訪問";
            elif [[ "$code" == "403" ]]; then result_color="${Y}"; result_text="被攔截 (403)";
            elif [[ "$code" == "429" ]]; then result_color="${Y}"; result_text="限流 (429)"; fi 
            ;;
        "Netflix")
            if [[ "$code" == "403" ]]; then
                result_color="${R}"; result_text="IP 被禁 (403)"
            elif [[ "$code" =~ ^(200|301|302)$ ]]; then
                local code2=$(curl "$iface" -sL -o /dev/null -w "%{http_code}" --max-time 5 -A "$ua" "https://www.netflix.com/title/70143836")
                if [[ "$code2" =~ ^(200|301|302)$ ]]; then
                    result_color="${G}"; result_text="完整解鎖 (全部劇集)"
                else
                    result_color="${Y}"; result_text="僅解鎖自製劇 (Originals)"
                fi
            else
                result_text="未知響應 ($code)"
            fi
            ;;
        "Disney+") 
            if [[ "$code" =~ ^(200|301|302)$ ]]; then result_color="${G}"; result_text="可用 (地區解鎖)"; else result_color="${R}"; result_text="不可用 (${code})"; fi 
            ;;
    esac

    tput cuu1; tput el; print_row "${name}" "${result_color}" "${result_text} ${time_label}"
}

check_chatgpt_full() {
    local iface=$1; print_row "ChatGPT" "${D}" "檢測中..."
    local ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    local start_time=$(date +%s%N)
    
    local code_web=$(curl "$iface" -sL -o /dev/null -w "%{http_code}" --max-time 5 -A "$ua" "https://chatgpt.com")
    if [[ "$code_web" == "403" ]]; then 
        local code_r=$(curl "$iface" -sL -o /dev/null -w "%{http_code}" --max-time 3 -A "$ua" "https://chatgpt.com/robots.txt")
        [[ "$code_r" == "200" ]] && code_web="200"
    fi
    local code_app=$(curl "$iface" -sL -o /dev/null -w "%{http_code}" --max-time 5 -A "$ua" "https://ios.chat.openai.com/public-api/mobile/server_status/v1")
    
    local end_time=$(date +%s%N); local duration=$(( (end_time - start_time) / 1000000 )); local time_label="(${duration}ms)"
    tput cuu1; tput el
    
    local web_ok=false; local app_ok=false
    [[ "$code_web" =~ ^(200|301|302|307)$ ]] && web_ok=true
    [[ "$code_app" == "200" ]] && app_ok=true
    
    if $web_ok && $app_ok; then print_row "ChatGPT" "${G}" "完整解鎖 (Web+App) $time_label"
    elif $web_ok; then print_row "ChatGPT" "${Y}" "僅解鎖 Web $time_label"
    elif $app_ok; then print_row "ChatGPT" "${Y}" "僅解鎖 App $time_label"
    else print_row "ChatGPT" "${R}" "失敗 (Web:${code_web} App:${code_app}) $time_label"; fi
}

tool_ip_check() {
    clear; print_banner
    echo -e " ${B}>>> 服務器 IP 質量檢測${N}"
    echo -e "${D}功能說明：檢測服務器 IP 是否被主流流媒體/AI 平台封鎖。${N}"; echo -e "${SEP}"
    
    check_interface() {
        local type=$1; local flag=$2
        if [[ -n "$type" ]]; then
            echo -e " ${P}[ IPv${flag//-/} ]${N}"
            
            local my_ip=""
            local my_isp=""
            
            local info=$(curl -s "$flag" --max-time 3 ipinfo.io/json)
            if [[ -n "$info" && "$info" != *"Rate limit"* ]]; then
                my_ip=$(echo "$info" | jq -r .ip 2>/dev/null)
                local org=$(echo "$info" | jq -r .org 2>/dev/null)
                local country=$(echo "$info" | jq -r .country 2>/dev/null)
                my_isp="${country} - ${org}"
            fi

            if [[ -z "$my_ip" || "$my_ip" == "null" ]]; then
                local fallback_host="api.ipify.org"
                if [[ "$flag" == "-6" ]]; then fallback_host="api64.ipify.org"; fi
                my_ip=$(curl -s "$flag" --max-time 3 "$fallback_host")
                my_isp="${D}ISP Unknown (API Limit)${N}"
            fi
            
            if [[ -z "$my_ip" ]]; then
                my_ip=$(curl -s "$flag" --max-time 3 ifconfig.co)
            fi

            if [[ -n "$my_ip" ]]; then
                print_row "本機 IP" "${W}" "${my_ip}"
                print_row "地區/ISP" "${Y}" "${my_isp}"
            else
                print_row "本機 IP" "${R}" "無法獲取 (All APIs Failed)"
            fi

            echo -e "${D}----------------------------------------------${N}"
            check_target "$flag" "Google" "https://www.google.com"
            check_target "$flag" "YouTube" "https://www.youtube.com"
            check_chatgpt_full "$flag"
            check_target "$flag" "Netflix" "https://www.netflix.com/title/80018499"
            check_target "$flag" "Disney+" "https://www.disneyplus.com"
        else
            echo -e " ${D}[ IPv${flag//-/} ] 無公網地址。${N}"
        fi
        echo ""
    }

    check_interface "${IPV4_ADDR}" "-4"
    check_interface "${IPV6_ADDR}" "-6"

    echo -e "${SEP}"; read -p " 按回車返回..."
}

tool_backup() {
    if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi
    
    while true; do
        clear; print_banner; echo -e " ${B}>>> 備份管理 (Backup Manager)${N}"
        echo -e "${D}功能說明：備份配置與證書。${N}"; echo -e "${SEP}"
        
        echo -e " ${P}現有備份記錄:${N}"
        local i=1; local backup_files=(); local has_files=false
        
        while read -r file; do
            if [[ -f "$file" ]]; then
                backup_files[i]="$file"
                local fname=$(basename "$file"); local fsize=$(du -h "$file" | awk '{print $1}')
                local ftime=$(date -r "$file" "+%Y-%m-%d %H:%M")
                echo -e "  ${C}[${i}]${N} ${D}${ftime}${N}  ${W}${fname}${N} (${fsize})"
                ((i++)); has_files=true
            fi
        done < <(ls -1t /root/prism_backup_*.tar.gz 2>/dev/null)

        if [[ "$has_files" == "false" ]]; then echo -e "  ${D}(暫無備份記錄)${N}"; fi
        
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}新建 備份${N}"
        if [[ "$has_files" == "true" ]]; then
            echo -e "  ${P}2.${N} ${R}刪除 備份${N}"
            echo -e "  ${P}3.${N} ${G}下載 備份${N} ${D}(本機 HTTPS 臨時服務器)${N}"
        fi
        echo -e "${SEP}"; echo -e "  ${P}0.${N} 返回"; echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        
        if [[ "$choice" == "0" ]]; then return; fi
        
        if [[ "$choice" == "1" ]]; then
            echo -ne " 確認創建新備份? [y/N]: "; read -r confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then continue; fi
            local fname="prism_backup_$(date +%Y%m%d_%H%M%S).tar.gz"; local fpath="/root/${fname}"
            
            mkdir -p "${WORK_DIR}/cert" "${WORK_DIR}/cert_acme"
            if tar -czf "$fpath" -C "${WORK_DIR}" conf/secrets.env cert cert_acme >/dev/null 2>&1; then 
                chmod 600 "$fpath"
                success "已創建: ${fname}"
            else 
                error "創建失敗"
            fi
            read -p " 按回車繼續..."

        elif [[ "$choice" == "2" && "$has_files" == "true" ]]; then
            read -p " 請輸入要刪除的編號: " idx
            local target="${backup_files[$idx]}"
            if [[ -f "$target" ]]; then rm -f "$target"; success "已刪除: $(basename "$target")"; else error "無效編號"; fi
            read -p " 按回車繼續..."

        elif [[ "$choice" == "3" && "$has_files" == "true" ]]; then
            read -p " 請輸入要下載的編號: " idx
            local target="${backup_files[$idx]}"
            if [[ ! -f "$target" ]]; then error "無效編號"; sleep 1; continue; fi
            local fname=$(basename "$target")
            
            echo ""; echo -e " ${Y}安全提示：${N} 將啟動臨時 HTTPS 服務器供您下載。"
            echo -e " 請確保您的 ACME 域名證書有效，且防火牆允許隨機高位端口。"
            
            local crt_file="${ACME_CERT_DIR}/${PRISM_ACME_DOMAIN}.crt"
            local key_file="${ACME_CERT_DIR}/${PRISM_ACME_DOMAIN}.key"
            
            if [[ -z "${PRISM_ACME_DOMAIN}" || ! -f "$crt_file" ]]; then 
                error "未檢測到 ACME 域名證書，無法啟動 HTTPS 服務。"
                echo -e " 建議使用 scp 命令下載: scp root@${IPV4_ADDR}:${target} ./"
            else
                local tmp_port=$((RANDOM % 10000 + 50000))
                local tmp_dir="${TEMP_DIR}/dl_$(date +%s)"
                mkdir -p "$tmp_dir"
                cp "$target" "$tmp_dir/"
                
                echo ""; info "正在啟動臨時安全服務器..."
                echo -e " 下載地址: ${G}https://${PRISM_ACME_DOMAIN}:${tmp_port}/${fname}${N}"
                echo -e " ${D}下載完成後，請按 Ctrl+C 停止服務。${N}"
                
                cd "$tmp_dir"
                openssl s_server -cert "$crt_file" -key "$key_file" -WWW -accept "$tmp_port" -quiet &
                local pid=$!
                trap "kill $pid 2>/dev/null; rm -rf $tmp_dir; echo -e '\n\n ${G}服務已停止${N}'; return" SIGINT
                wait $pid 2>/dev/null
            fi
            read -p " 按回車繼續..."
        else error "無效輸入"; sleep 1; fi
    done
}

tool_cleanup() {
    echo ""; info "正在清理系統..."
    echo "" > "${LOG_FILE}"; echo "" > "${WORK_DIR}/box.log"
    rm -f "${WORK_DIR}/cache.db"; rm -f "${WORK_DIR}/temp_client.json"; rm -f "${TEMP_DIR}"/* 2>/dev/null
    rm -f "${CACHE_FILE}"
    success "清理完成"; sleep 1
}

tool_swap() {
    clear; print_banner; echo -e " ${B}>>> 虛擬內存 (Swap) 管理${N}"
    echo -e "${D}功能說明：使用硬盤空間模擬內存，防止小內存機器崩潰。${N}"
    echo -e "${SEP}"
    local s=$(free -m | grep Swap | awk '{print $2}')
    echo -e " 當前 Swap: ${C}${s} MB${N}"; echo -e "${SEP}"
    echo -e "  ${P}1.${N} ${W}添加/設置 Swap${N}"; echo -e "  ${P}2.${N} ${W}刪除 Swap${N}"; echo -e "${SEP}"; echo -e "  ${P}0.${N} 返回"; echo -e "${SEP}"
    echo -ne " 請輸入選項: "; read -r c
    if [[ "$c" == "0" ]]; then return; fi

    case "$c" in
        1)
            echo ""; read -p " 請輸入大小 (MB): " sz
            if [[ ! "$sz" =~ ^[0-9]+$ ]]; then error "無效"; return; fi
            info "創建中..."; swapoff -a; dd if=/dev/zero of=/swapfile bs=1M count=$sz status=progress; chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
            if ! grep -q "/swapfile" /etc/fstab; then echo "/swapfile none swap sw 0 0" >> /etc/fstab; fi
            sysctl vm.swappiness=10 >/dev/null; echo "vm.swappiness=10" > /etc/sysctl.d/99-prism-swap.conf
            success "成功"; read -p " 按回車返回..." ;;
        2)
            info "刪除中..."; swapoff -a; rm -f /swapfile; sed -i '/\/swapfile/d' /etc/fstab; rm -f /etc/sysctl.d/99-prism-swap.conf; success "已刪除"; read -p " 按回車返回..." ;;
        *) error "無效輸入"; sleep 1 ;;
    esac
}

tool_fail2ban() {
    if [[ -z "${PKG_MANAGER}" ]]; then detect_os; fi
    
    while true; do
        clear; print_banner; echo -e " ${B}>>> Fail2Ban 防護${N}"; echo -e "${SEP}"
        
        local st="${R}未安裝${N}"
        if command -v fail2ban-server &>/dev/null; then 
            if systemctl is-active --quiet fail2ban; then st="${G}運行中${N}"; else st="${Y}已停止${N}"; fi
        fi
        
        echo -e " 狀態: ${st}"; echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}安裝並開啟${N}"
        echo -e "  ${P}2.${N} ${W}卸載${N}"
        echo -e "  ${P}3.${N} ${W}查看封禁列表${N} ${D}(原生樣式+中文)${N}"
        echo -e "${SEP}"; echo -e "  ${P}0.${N} 返回"; echo -e "${SEP}"
        echo -ne " 選項: "; read -r c
        
        if [[ "$c" == "0" ]]; then return; fi
        
        case "$c" in
            1) 
                info "安裝中..."
                if [[ -n "${PKG_UPDATE_CMD}" ]]; then ${PKG_UPDATE_CMD} >/dev/null; fi
                ${PKG_INSTALL_CMD} fail2ban >/dev/null 2>&1
                
                if ! command -v fail2ban-server &>/dev/null; then error "安裝失敗"; return; fi
                
                cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 86400
findtime = 600
EOF
                if [[ -f /var/log/secure ]]; then sed -i 's|/var/log/auth.log|/var/log/secure|' /etc/fail2ban/jail.d/sshd.local; fi
                
                systemctl enable fail2ban; systemctl restart fail2ban
                success "已啟動"
                read -p " 按回車返回..." 
                ;;
                
            2) 
                info "卸載中..."
                systemctl stop fail2ban
                if [[ "${PKG_MANAGER}" == "apt" ]]; then apt-get remove -y fail2ban; else yum remove -y fail2ban; fi
                rm -rf /etc/fail2ban
                success "已卸載"
                read -p " 按回車返回..." 
                ;;
                
            3)
                if ! command -v fail2ban-client &>/dev/null; then warn "未安裝"; read -p " 按回車返回..."; continue; fi
                
                local raw=$(fail2ban-client status sshd 2>/dev/null)
                
                if [[ -z "$raw" ]]; then
                    error "無法獲取狀態 (服務可能未啟動)"
                    read -p " 按回車返回..."; continue
                fi

                local failed_now=$(echo "$raw" | grep "Currently failed:" | awk '{print $NF}')
                local failed_total=$(echo "$raw" | grep "Total failed:" | awk '{print $NF}')
                local banned_now=$(echo "$raw" | grep "Currently banned:" | awk '{print $NF}')
                local banned_total=$(echo "$raw" | grep "Total banned:" | awk '{print $NF}')
                local ip_list=$(echo "$raw" | grep "Banned IP list:" | sed 's/.*Banned IP list:\s*//')
                
                clear; print_banner
                echo -e " ${P}>>> Fail2Ban Status (SSHD 監控狀態)${N}"
                echo -e "${SEP}"
                
                echo -e " Status for the jail: sshd"
                echo -e " |- ${W}Filter${N} ${D}(過濾統計)${N}"
                echo -e " |  |- Currently failed: ${Y}${failed_now:-0}${N}   ${D}(當前失敗嘗試)${N}"
                echo -e " |  \`- Total failed:     ${Y}${failed_total:-0}${N} ${D}(累計失敗嘗試)${N}"
                echo -e " \`- ${W}Actions${N} ${D}(執行動作)${N}"
                echo -e "    |- Currently banned: ${R}${banned_now:-0}${N}   ${D}(當前被封禁數)${N}"
                echo -e "    |- Total banned:     ${R}${banned_total:-0}${N} ${D}(累計被封禁數)${N}"
                echo -e "    \`- ${W}Banned IP list:${N}   ${D}(封禁 IP 列表)${N}"
                
                if [[ -z "${ip_list// /}" ]]; then
                    echo -e "       ${G}(None/無)${N}"
                else
                    echo -e "${D}       --------------------------------------------------${N}"
                    echo "${ip_list}" | fold -s -w 65 | sed 's/^/       /' | while read -r line; do
                        echo -e "${Y}${line}${N}"
                    done
                fi
                
                echo -e "${SEP}"
                read -p " 按回車返回..." 
                ;;
                
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
}

tool_timezone() {
    echo ""; info "正在同步時間..."
    timedatectl set-timezone Asia/Shanghai
    if command -v ntpdate &>/dev/null; then ntpdate pool.ntp.org; fi
    success "時區已設置為: $(date)"
    sleep 1.5
}

submenu_tool() {
    while true; do
        clear; print_banner
        echo -e " ${B}>>> 實用工具箱 (Toolbox)${N}"; echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}流媒體/IP檢測${N}     ${D}(原生檢測/無外部依賴)${N}"
        echo -e "  ${P}2.${N} ${W}虛擬內存 (Swap)${N}   ${D}(弱雞適用)${N}"
        echo -e "  ${P}3.${N} ${Y}Fail2Ban 防護${N}     ${D}(SSH 安全防護)${N}"
        echo -e "  ${P}4.${N} ${W}校準服務器時間${N}    ${D}(Asia/Shanghai)${N}"
        echo -e "  ${P}5.${N} ${W}BBR 加速與優化${N}    ${D}(原版BBR/XanMod-BBRv3)${N}"
        echo -e "  ${P}6.${N} ${W}系統清理${N}          ${D}(清空日誌/緩存)${N}"
        echo -e "  ${P}7.${N} ${G}配置備份${N}          ${D}(導出密鑰與證書)${N}"
        echo -e "${SEP}"; echo -e "  ${P}0.${N} 返回主菜單"; echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        case "$choice" in
            1) tool_ip_check ;; 2) tool_swap ;; 3) tool_fail2ban ;; 4) tool_timezone ;;
            5) 
                if declare -f action_bbr > /dev/null; then 
                    action_bbr 
                else 
                    error "BBR 模塊未加載"; sleep 1
                fi 
                ;;
            6) tool_cleanup ;; 7) tool_backup ;;
            0) break ;; *) error "無效輸入"; sleep 1 ;;
        esac
    done
    show_menu
}
