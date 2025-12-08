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

is_valid_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        [[ ${octets[0]} -le 255 && ${octets[1]} -le 255 && ${octets[2]} -le 255 && ${octets[3]} -le 255 ]]
        return $?
    fi
    return 1
}

is_valid_port() {
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; then return 0; fi
    return 1
}

sanitize_domain_list() {
    local input="$1"
    echo "$input" | tr '，' ',' | tr -d ' '
}

apply_routing_changes() {
    if [[ -f "${BASE_DIR}/modules/config.sh" ]]; then source "${BASE_DIR}/modules/config.sh"; fi
    
    if declare -f build_config > /dev/null; then 
        info "正在更新路由規則..."
        build_config
        systemctl restart sing-box
        success "路由策略已應用"
        sleep 1.5
    else
        error "無法應用路由：config.sh 模塊加載失敗"
    fi
    
    if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi
}

install_warp_core() {
    if [[ -f "${WARP_REG_BIN}" ]]; then
        if [[ -x "${WARP_REG_BIN}" ]]; then
            true
        else
            rm -f "${WARP_REG_BIN}"
        fi
    fi

    if [[ ! -f "${WARP_REG_BIN}" ]]; then
        info "正在下載 WARP 註冊工具 (Self-Hosted)..."
        
        local arch=$(uname -m)
        local download_url=""
        
        local BASE_URL="https://github.com/Yat-Muk/warp-reg/releases/download/v1.6"
        
        case "$arch" in
            x86_64|amd64) 
                download_url="${BASE_URL}/warp-reg-linux-amd64" 
                ;;
            aarch64|arm64) 
                download_url="${BASE_URL}/warp-reg-linux-arm64" 
                ;;
            *) 
                error "不支持的 CPU 架構: $arch"
                return 1 
                ;;
        esac
        
        if wget -q -O "${WARP_REG_BIN}" "${download_url}"; then
            chmod +x "${WARP_REG_BIN}"
            success "下載完成"
        else
            error "下載失敗，請檢查網絡連接或 GitHub Release 地址"
            return 1
        fi
    fi
    
    info "正在註冊 WARP 賬戶..."
    local warp_out=$("${WARP_REG_BIN}")
    
    local private_key=$(echo "$warp_out" | grep "private_key" | cut -d: -f2 | tr -d ' ",')
    local public_key=$(echo "$warp_out" | grep "public_key" | cut -d: -f2 | tr -d ' ",')
    local v6=$(echo "$warp_out" | grep "v6" | cut -d: -f2- | tr -d ' ",')
    local reserved=$(echo "$warp_out" | grep "reserved" | cut -d: -f2 | tr -d ' "')
    
    if [[ -z "$reserved" ]]; then reserved="[0,0,0]"; fi
    
    if [[ -n "$private_key" ]]; then
        success "WARP 註冊成功！"
        write_secret_no_apply "PRISM_WARP_ENABLE" "true"
        write_secret_no_apply "PRISM_WARP_PRIVATE_KEY" "${private_key}"
        write_secret_no_apply "PRISM_WARP_PUBLIC_KEY" "${public_key}"
        write_secret_no_apply "PRISM_WARP_IPV6_ADDR" "${v6}"
        write_secret_no_apply "PRISM_WARP_RESERVED" "${reserved}"
        return 0
    else
        error "WARP 註冊失敗，接口響應異常。"
        return 1
    fi
}

manage_rule_file() {
    local rule_file="$1"; local rule_name="$2"; local action="$3"
    local file_path="${RULE_DIR}/${rule_file}"
    mkdir -p "${RULE_DIR}"; if [[ ! -f "${file_path}" ]]; then touch "${file_path}"; fi

    if [[ "$action" == "view" ]]; then
        clear; print_banner
        echo -e " ${P}>>> 查看規則: ${W}${rule_name}${N}"
        echo -e "${SEP}"
        if [[ ! -s "${file_path}" ]]; then echo -e "  ${D}(當前規則列表為空)${N}"; else
            local line_count=$(wc -l < "${file_path}")
            echo -e "  ${G}當前包含 ${line_count} 條規則:${N}"
            echo -e "${D}------------------------------------${N}"
            head -n 20 "${file_path}" | while read -r line; do echo -e "  - ${line}"; done
            if [[ "$line_count" -gt 20 ]]; then echo -e "  ${D}... (更多)${N}"; fi
        fi
        echo -e "${SEP}"
        read -p "按回車返回..."
        return
    fi
    
    if [[ "$action" == "add" ]]; then
        clear; print_banner
        echo -e " ${P}>>> 添加規則: ${W}${rule_name}${N}"
        echo -e "${SEP}"
        echo -e "${D}功能說明：批量添加域名到 ${rule_name} 規則列表${N}"
        echo -e " ${Y}請輸入域名 (逗號分隔，輸入 0 取消)${N}"
        echo -e " ${D}示例: netflix.com, openai.com${N}"
        echo -e "${SEP}"
        
        read -p " > " input_domains
        
        if [[ "$input_domains" == "0" ]]; then return; fi
        
        local clean_domains=$(sanitize_domain_list "$input_domains")
        if [[ -n "$clean_domains" ]]; then
            echo "$clean_domains" | tr ',' '\n' | sed '/^$/d' >> "${file_path}"
            sort -u "${file_path}" -o "${file_path}"
            apply_routing_changes
        else
            warn "輸入為空"; sleep 1
        fi
    fi
}

menu_warp_sub() {
    local type="$1"
    if [[ "${PRISM_WARP_ENABLE:-}" != "true" ]]; then
        if install_warp_core; then
            write_secret_no_apply "PRISM_WARP_TYPE" "${type}"
            apply_routing_changes
        else return; fi
    fi
    while true; do
        clear; print_banner
        local global_status="${D}[關閉]${N}"
        if [[ "${PRISM_WARP_GLOBAL:-}" == "true" ]]; then global_status="${G}[開啟]${N}"; fi
        echo -e " ${P}>>> WARP 分流管理 (${W}${type}${P})${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}查看已分流域名${N}"
        echo -e "  ${P}2.${N} ${W}添加分流域名${N}"
        echo -e "  ${P}3.${N} ${W}設置 WARP 全局${N}   ${global_status}"
        echo -e "  ${P}4.${N} ${R}卸載 WARP 分流${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r sub_c
        case "$sub_c" in
            1) manage_rule_file "warp.list" "WARP" "view" ;;
            2) manage_rule_file "warp.list" "WARP" "add" ;;
            3) local new_state="true"; if [[ "${PRISM_WARP_GLOBAL:-}" == "true" ]]; then new_state="false"; fi; write_secret_no_apply "PRISM_WARP_GLOBAL" "$new_state"; apply_routing_changes ;;
            4) write_secret_no_apply "PRISM_WARP_ENABLE" "false"; write_secret_no_apply "PRISM_WARP_GLOBAL" "false"; apply_routing_changes; break ;;
            0) break ;;
        esac
    done
}

menu_ipv6_sub() {
    while true; do
        clear; print_banner
        local global_status="${D}[關閉]${N}"
        if [[ "${PRISM_IPV6_GLOBAL:-}" == "true" ]]; then global_status="${G}[開啟]${N}"; fi
        echo -e " ${P}>>> IPv6 分流管理${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}查看已分流域名${N}"
        echo -e "  ${P}2.${N} ${W}添加分流域名${N}"
        echo -e "  ${P}3.${N} ${W}設置 IPv6 全局${N}    ${global_status}"
        echo -e "  ${P}4.${N} ${R}卸載 IPv6 分流${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r sub_c
        case "$sub_c" in
            1) manage_rule_file "ipv6.list" "IPv6" "view" ;;
            2) manage_rule_file "ipv6.list" "IPv6" "add" ;;
            3) local new_state="true"; if [[ "${PRISM_IPV6_GLOBAL:-}" == "true" ]]; then new_state="false"; fi; write_secret_no_apply "PRISM_IPV6_GLOBAL" "$new_state"; apply_routing_changes ;;
            4) > "${RULE_DIR}/ipv6.list"; write_secret_no_apply "PRISM_IPV6_GLOBAL" "false"; apply_routing_changes; break ;;
            0) break ;;
        esac
    done
}

menu_socks5_out_sub() {
    while true; do
        clear; print_banner
        local status="${D}[未配置]${N}"
        if [[ "${PRISM_SOCKS5_OUT_ENABLE:-}" == "true" ]]; then status="${G}[已配置]${N}"; fi
        local global_status="${D}[關閉]${N}"
        if [[ "${PRISM_SOCKS5_OUT_GLOBAL:-}" == "true" ]]; then global_status="${G}[開啟]${N}"; fi
        
        echo -e " ${P}>>> Socks5 出站 (Outbound)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}安裝/配置 Socks5 出站${N}   ${status}"
        echo -e "  ${P}2.${N} ${W}設置 Socks5 全局轉發${N}    ${global_status}"
        echo -e "  ${P}3.${N} ${W}分流規則管理${N}"
        echo -e "  ${P}4.${N} ${R}卸載 Socks5 出站${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r sub_c
        
        case "$sub_c" in
            1) 
                echo ""; echo -e "${D}功能說明：配置外部 Socks5 代理作為出站節點${N}"
                while true; do 
                    read -p "請輸入落地機 IP (回車 127.0.0.1，輸入 0 取消): " ip
                    if [[ "$ip" == "0" ]]; then continue 2; fi
                    ip=${ip:-127.0.0.1}
                    if is_valid_ip "$ip"; then break; else error "IP 格式錯誤"; fi
                done
                
                while true; do 
                    read -p "請輸入落地機端口 (回車 1080): " pt
                    pt=${pt:-1080}
                    if is_valid_port "$pt"; then break; else error "端口無效 (1-65535)"; fi
                done
                
                read -p "請輸入 用戶名 (回車空): " u
                read -p "請輸入 密碼 (回車空): " p
                
                write_secret_no_apply "PRISM_SOCKS5_OUT_ENABLE" "true"
                write_secret_no_apply "PRISM_SOCKS5_OUT_IP" "${ip}"
                write_secret_no_apply "PRISM_SOCKS5_OUT_PORT" "${pt}"
                write_secret_no_apply "PRISM_SOCKS5_OUT_USER" "${u}"
                write_secret_no_apply "PRISM_SOCKS5_OUT_PASS" "${p}"
                apply_routing_changes 
                ;;
            2) 
                if [[ "${PRISM_SOCKS5_OUT_ENABLE}" != "true" ]]; then error "請先配置 Socks5 出站"; sleep 1; continue; fi
                local new_state="true"; if [[ "${PRISM_SOCKS5_OUT_GLOBAL:-}" == "true" ]]; then new_state="false"; fi
                write_secret_no_apply "PRISM_SOCKS5_OUT_GLOBAL" "$new_state"
                apply_routing_changes 
                ;;
            3) 
                echo -e "\n  ${P}1.${N} 查看規則\n  ${P}2.${N} 添加規則"
                read -p " 選擇: " r_opt
                if [[ "$r_opt" == "1" ]]; then manage_rule_file "socks5_out.list" "Socks5出站" "view"; fi
                if [[ "$r_opt" == "2" ]]; then manage_rule_file "socks5_out.list" "Socks5出站" "add"; fi 
                ;;
            4) 
                write_secret_no_apply "PRISM_SOCKS5_OUT_ENABLE" "false"
                write_secret_no_apply "PRISM_SOCKS5_OUT_GLOBAL" "false"
                apply_routing_changes
                break ;;
            0) break ;;
        esac
    done
}

menu_socks5_in_sub() {
    while true; do
        clear; print_banner
        local status="${D}[未啟用]${N}"
        if [[ "${PRISM_SOCKS5_IN_ENABLE:-}" == "true" ]]; then status="${G}[運行中: ${PRISM_SOCKS5_IN_PORT}]${N}"; fi
        echo -e " ${P}>>> Socks5 入站 (Inbound)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}配置 Socks5 入站${N}   ${status}"
        echo -e "  ${P}2.${N} ${W}入站白名單管理${N}"
        echo -e "  ${P}3.${N} ${W}查看入站信息${N}"
        echo -e "  ${P}4.${N} ${R}卸載 Socks5 入站${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r sub_c
        case "$sub_c" in
            1) 
                echo ""; echo -e "${D}功能說明：開啟一個 Socks5 服務器供外部連接${N}"
                while true; do 
                    read -p "端口 (回車隨機，輸入 0 取消): " pt
                    if [[ "$pt" == "0" ]]; then continue 2; fi
                    pt=${pt:-$((RANDOM % 10000 + 20000))}
                    if is_valid_port "$pt"; then break; else error "端口無效"; fi
                done
                
                read -p "User (回車 prism): " u; u=${u:-prism}
                read -p "Pass (回車隨機): " p; if [[ -z "$p" ]]; then p=$(openssl rand -hex 8); fi
                
                write_secret_no_apply "PRISM_SOCKS5_IN_ENABLE" "true"
                write_secret_no_apply "PRISM_SOCKS5_IN_PORT" "${pt}"
                write_secret_no_apply "PRISM_SOCKS5_IN_USER" "${u}"
                write_secret_no_apply "PRISM_SOCKS5_IN_PASS" "${p}"
                apply_routing_changes 
                ;;
            2) 
                echo -e "\n  ${P}1.${N} 查看規則\n  ${P}2.${N} 添加規則"
                read -p " 選擇: " r_opt
                if [[ "$r_opt" == "1" ]]; then manage_rule_file "socks5_in.list" "Socks5入站" "view"; fi
                if [[ "$r_opt" == "2" ]]; then manage_rule_file "socks5_in.list" "Socks5入站" "add"; fi 
                ;;
            3) 
                if [[ "${PRISM_SOCKS5_IN_ENABLE}" == "true" ]]; then 
                    echo -e "\n ${G}Socks5 入站配置:${N}"
                    echo -e " 端口: ${Y}${PRISM_SOCKS5_IN_PORT}${N}"
                    echo -e " 用戶: ${Y}${PRISM_SOCKS5_IN_USER}${N}"
                    echo -e " 密碼: ${Y}${PRISM_SOCKS5_IN_PASS}${N}"
                else 
                    warn "未安裝"
                fi
                read -p "按回車..." ;;
            4) 
                write_secret_no_apply "PRISM_SOCKS5_IN_ENABLE" "false"
                apply_routing_changes
                break ;;
            0) break ;;
        esac
    done
}

menu_dns_sub() {
    while true; do
        clear; print_banner
        echo -e " ${P}>>> DNS 分流${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}添加 DNS 分流規則${N}"
        echo -e "  ${P}2.${N} ${R}卸載 DNS 分流${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        case "$choice" in
            1) 
                echo ""; echo -e "${D}功能說明：將特定域名解析指向特定 DNS 服務器${N}"
                while true; do 
                    read -p "DNS IP (如 8.8.8.8，輸入 0 取消): " dip
                    if [[ "$dip" == "0" ]]; then continue 2; fi
                    if is_valid_ip "$dip"; then break; else error "無效 IP"; fi
                done
                
                read -p "域名 (逗號分隔): " dlist
                local clean_domains=$(sanitize_domain_list "$dlist")
                if [[ -n "$clean_domains" ]]; then 
                    write_secret_no_apply "PRISM_DNS_ENABLE" "true"
                    write_secret_no_apply "PRISM_DNS_IP" "${dip}"
                    echo "$clean_domains" | tr ',' '\n' > "${RULE_DIR}/dns.list"
                    apply_routing_changes
                else warn "域名為空"; sleep 1; fi 
                ;;
            2) 
                write_secret_no_apply "PRISM_DNS_ENABLE" "false"
                rm -f "${RULE_DIR}/dns.list"
                apply_routing_changes
                break ;;
            0) break ;;
        esac
    done
}

menu_sni_sub() {
    while true; do
        clear; print_banner
        echo -e " ${P}>>> SNI 反向代理分流 (IP Redirect)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}添加 SNI 分流規則${N}"
        echo -e "  ${P}2.${N} ${R}卸載 SNI 分流${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        case "$choice" in
            1) 
                echo ""; echo -e "${D}功能說明：將特定域名的 IP 強制解析為指定的反代 IP${N}"
                while true; do
                    read -p "反代 IP (例如 Netflix 解鎖 IP，輸入 0 取消): " sip
                    if [[ "$sip" == "0" ]]; then continue 2; fi 
                    if is_valid_ip "$sip"; then break; else error "無效 IP"; fi
                done
                read -p "域名 (逗號分隔): " slist
                local clean_domains=$(sanitize_domain_list "$slist")
                
                if [[ -n "$clean_domains" ]]; then
                    write_secret_no_apply "PRISM_SNI_ENABLE" "true"
                    write_secret_no_apply "PRISM_SNI_IP" "${sip}"
                    echo "$clean_domains" | tr ',' '\n' > "${RULE_DIR}/sni.list"
                    apply_routing_changes
                else warn "域名為空"; sleep 1; fi
                ;;
            2) 
                write_secret_no_apply "PRISM_SNI_ENABLE" "false"
                rm -f "${RULE_DIR}/sni.list"
                apply_routing_changes
                break ;;
            0) break ;;
        esac
    done
}

submenu_routing() {
    while true; do
        clear; print_banner
        
        local warp_status="${D}[未啟用]${N}"
        if [[ "${PRISM_WARP_ENABLE:-}" == "true" ]]; then warp_status="${G}[已啟用]${N}"; fi
        
        echo -e " ${P}>>> 分流工具箱 (Routing Tools)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}WARP 分流 (IPv4)${N}  ${warp_status}"
        echo -e "  ${P}2.${N} ${W}WARP 分流 (IPv6)${N}"
        echo -e "  ${P}3.${N} ${W}IPv6 分流${N}        ${D}(指定域名走 IPv6)${N}"
        echo -e "  ${P}4.${N} ${W}Socks5 出站${N}      ${D}(連接外部代理)${N}"
        echo -e "  ${P}5.${N} ${W}Socks5 入站${N}      ${D}(作為代理服務器)${N}"
        echo -e "  ${P}6.${N} ${W}DNS 分流${N}         ${D}(指定域名用特殊 DNS)${N}"
        echo -e "  ${P}7.${N} ${W}SNI 反代分流${N}     ${D}(強制解析域名到IP)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        
        case "$choice" in
            1) menu_warp_sub "IPv4" ;;
            2) menu_warp_sub "IPv6" ;;
            3) menu_ipv6_sub ;;
            4) menu_socks5_out_sub ;;
            5) menu_socks5_in_sub ;;
            6) menu_dns_sub ;;
            7) menu_sni_sub ;;
            0) break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
    show_menu
}
