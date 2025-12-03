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

is_valid_ip() {
    local ip=$1
    local stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

is_valid_port() {
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

echoContent() {
    case $1 in
        "red") echo -e "${R}$2${N}" ;;
        "skyBlue") echo -e "${C}$2${N}" ;;
        "green") echo -e "${G}$2${N}" ;;
        "yellow") echo -e "${Y}$2${N}" ;;
    esac
}

install_warp_core() {
    if [[ ! -f "${WARP_REG_BIN}" ]]; then
        echoContent skyBlue "正在下載 WARP 註冊工具..."
        local arch=$(uname -m)
        local warp_url=""
        if [[ "$arch" == "x86_64" ]]; then warp_url="https://github.com/badafans/warp-reg/releases/download/v1.0/main-linux-amd64"; fi
        if [[ "$arch" == "aarch64" ]]; then warp_url="https://github.com/badafans/warp-reg/releases/download/v1.0/main-linux-arm64"; fi
        
        if [[ -z "$warp_url" ]]; then echoContent red "不支持的架構: $arch"; return 1; fi
        wget -q -O "${WARP_REG_BIN}" "${warp_url}"; chmod +x "${WARP_REG_BIN}"
    fi
    
    echoContent skyBlue "正在註冊 WARP 賬戶..."
    local warp_out=$("${WARP_REG_BIN}")
    local private_key=$(echo "$warp_out" | grep "private_key" | cut -d: -f2 | tr -d ' "')
    local public_key=$(echo "$warp_out" | grep "public_key" | cut -d: -f2 | tr -d ' "')
    local v6=$(echo "$warp_out" | grep "v6" | cut -d: -f2- | tr -d ' "')
    local reserved=$(echo "$warp_out" | grep "reserved" | cut -d: -f2 | tr -d ' "')
    
    if [[ -z "$reserved" ]]; then reserved="[0,0,0]"; fi
    
    if [[ -n "$private_key" ]]; then
        echoContent green "WARP 註冊成功！"
        sed -i '/export PRISM_WARP_/d' "${CONFIG_DIR}/secrets.env"
        cat >> "${CONFIG_DIR}/secrets.env" <<EOF
export PRISM_WARP_ENABLE="true"
export PRISM_WARP_PRIVATE_KEY="${private_key}"
export PRISM_WARP_PUBLIC_KEY="${public_key}"
export PRISM_WARP_IPV6_ADDR="${v6}"
export PRISM_WARP_RESERVED="${reserved}"
EOF
        return 0
    else
        echoContent red "WARP 註冊失敗。"
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
        echo -e " ${Y}請輸入域名 (支持批量，逗號/空格分隔)${N}"
        echo -e " ${D}示例: netflix.com, openai.com${N}"
        echo -e "${SEP}"
        read -p " > " new_domains
        if [[ -n "$new_domains" ]]; then
            echo "$new_domains" | tr ',' '\n' | tr ' ' '\n' | sed '/^$/d' >> "${file_path}"
            sort -u "${file_path}" -o "${file_path}"
            if [[ -f "${BASE_DIR}/modules/config.sh" ]]; then source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "規則已添加並應用"; fi
            sleep 1.5
        else
            warn "未輸入內容"
            sleep 1
        fi
    fi
}

menu_warp_sub() {
    local type="$1"
    if [[ "${PRISM_WARP_ENABLE:-}" != "true" ]]; then
        if install_warp_core; then
            sed -i '/export PRISM_WARP_TYPE/d' "${CONFIG_DIR}/secrets.env"
            echo "export PRISM_WARP_TYPE=\"${type}\"" >> "${CONFIG_DIR}/secrets.env"
            source "${CONFIG_DIR}/secrets.env"
            source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism
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
        echo -e "${D}  ------------------------------------${N}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r sub_c
        
        case "$sub_c" in
            1) manage_rule_file "warp.list" "WARP" "view" ;;
            2) manage_rule_file "warp.list" "WARP" "add" ;;
            3) 
                if [[ "${PRISM_WARP_GLOBAL:-}" == "true" ]]; then
                    sed -i '/export PRISM_WARP_GLOBAL/d' "${CONFIG_DIR}/secrets.env"; echo "export PRISM_WARP_GLOBAL=\"false\"" >> "${CONFIG_DIR}/secrets.env"
                    echoContent yellow "正在關閉全局 WARP..."
                else
                    sed -i '/export PRISM_WARP_GLOBAL/d' "${CONFIG_DIR}/secrets.env"; echo "export PRISM_WARP_GLOBAL=\"true\"" >> "${CONFIG_DIR}/secrets.env"
                    echoContent green "正在開啟全局 WARP..."
                fi
                source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "狀態已更新"; sleep 1.5 
                source "${CONFIG_DIR}/secrets.env"
                ;;
            4) 
                sed -i '/export PRISM_WARP_ENABLE/d' "${CONFIG_DIR}/secrets.env"
                sed -i '/export PRISM_WARP_GLOBAL/d' "${CONFIG_DIR}/secrets.env"
                echo "export PRISM_WARP_ENABLE=\"false\"" >> "${CONFIG_DIR}/secrets.env"
                source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "卸載完畢"; break ;;
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
        echo -e "${D}  ------------------------------------${N}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r sub_c
        
        case "$sub_c" in
            1) manage_rule_file "ipv6.list" "IPv6" "view" ;;
            2) manage_rule_file "ipv6.list" "IPv6" "add" ;;
            3) 
                if [[ "${PRISM_IPV6_GLOBAL:-}" == "true" ]]; then
                     sed -i '/export PRISM_IPV6_GLOBAL/d' "${CONFIG_DIR}/secrets.env"; echo "export PRISM_IPV6_GLOBAL=\"false\"" >> "${CONFIG_DIR}/secrets.env"
                else
                     sed -i '/export PRISM_IPV6_GLOBAL/d' "${CONFIG_DIR}/secrets.env"; echo "export PRISM_IPV6_GLOBAL=\"true\"" >> "${CONFIG_DIR}/secrets.env"
                fi
                source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "狀態已更新"; sleep 1; source "${CONFIG_DIR}/secrets.env" ;;
            4) > "${RULE_DIR}/ipv6.list"; sed -i '/export PRISM_IPV6_GLOBAL/d' "${CONFIG_DIR}/secrets.env"; source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "卸載完畢"; break ;;
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
        echo -e "  ${P}3.${N} ${W}查看分流規則${N}"
        echo -e "  ${P}4.${N} ${W}添加分流規則${N}"
        echo -e "  ${P}5.${N} ${R}卸載 Socks5 出站${N}"
        echo -e "${D}  ------------------------------------${N}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r sub_c
        
        case "$sub_c" in
            1) 
                echo "";
                while true; do
                    read -p "請輸入落地機 IP (回車 127.0.0.1): " ip
                    ip=${ip:-127.0.0.1}
                    if is_valid_ip "$ip"; then break; else echoContent red "IP 格式錯誤"; fi
                done
                
                while true; do
                    read -p "請輸入落地機端口 (回車 1080): " pt
                    pt=${pt:-1080}
                    if is_valid_port "$pt"; then break; else echoContent red "端口無效 (1-65535)"; fi
                done

                read -p "請輸入 用戶名 (回車空): " u
                read -p "請輸入 密碼 (回車空): " p
                
                sed -i '/export PRISM_SOCKS5_OUT_/d' "${CONFIG_DIR}/secrets.env"
                cat >> "${CONFIG_DIR}/secrets.env" <<EOF
export PRISM_SOCKS5_OUT_ENABLE="true"
export PRISM_SOCKS5_OUT_IP="${ip}"
export PRISM_SOCKS5_OUT_PORT="${pt}"
export PRISM_SOCKS5_OUT_USER="${u}"
export PRISM_SOCKS5_OUT_PASS="${p}"
EOF
                export PRISM_SOCKS5_OUT_ENABLE="true"
                source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "配置已保存"; sleep 1; source "${CONFIG_DIR}/secrets.env" ;;
            2) 
               if [[ "${PRISM_SOCKS5_OUT_ENABLE}" != "true" ]]; then error "請先安裝 Socks5 出站"; sleep 1; continue; fi
               if [[ "${PRISM_SOCKS5_OUT_GLOBAL:-}" == "true" ]]; then
                    sed -i '/export PRISM_SOCKS5_OUT_GLOBAL/d' "${CONFIG_DIR}/secrets.env"; echo "export PRISM_SOCKS5_OUT_GLOBAL=\"false\"" >> "${CONFIG_DIR}/secrets.env"
               else
                    sed -i '/export PRISM_SOCKS5_OUT_GLOBAL/d' "${CONFIG_DIR}/secrets.env"; echo "export PRISM_SOCKS5_OUT_GLOBAL=\"true\"" >> "${CONFIG_DIR}/secrets.env"
               fi
               source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "狀態已更新"; sleep 1; source "${CONFIG_DIR}/secrets.env" ;;
            3) manage_rule_file "socks5_out.list" "Socks5出站" "view" ;;
            4) manage_rule_file "socks5_out.list" "Socks5出站" "add" ;;
            5) 
                sed -i '/export PRISM_SOCKS5_OUT_/d' "${CONFIG_DIR}/secrets.env"
                export PRISM_SOCKS5_OUT_ENABLE="false"
                export PRISM_SOCKS5_OUT_GLOBAL="false"
                source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "已卸載"; sleep 1; break ;;
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
        echo -e "  ${P}1.${N} ${W}安裝/配置 Socks5 入站${N}   ${status}"
        echo -e "  ${P}2.${N} ${W}查看分流規則${N}       ${D}(白名單)${N}"
        echo -e "  ${P}3.${N} ${W}添加分流規則${N}       ${D}(白名單)${N}"
        echo -e "  ${P}4.${N} ${W}查看入站配置${N}       ${D}(賬號信息)${N}"
        echo -e "  ${P}5.${N} ${R}卸載 Socks5 入站${N}"
        echo -e "${D}  ------------------------------------${N}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r sub_c
        
        case "$sub_c" in
            1) 
                echo ""; 
                while true; do
                    read -p "端口 (回車隨機): " pt
                    pt=${pt:-$((RANDOM % 10000 + 20000))}
                    if is_valid_port "$pt"; then break; else echoContent red "端口無效"; fi
                done
                read -p "User (回車 prism): " u; u=${u:-prism}
                read -p "Pass (回車隨機): " p; if [[ -z "$p" ]]; then p=$(openssl rand -hex 8); fi
                
                sed -i '/export PRISM_SOCKS5_IN_/d' "${CONFIG_DIR}/secrets.env"; cat >> "${CONFIG_DIR}/secrets.env" <<EOF
export PRISM_SOCKS5_IN_ENABLE="true"
export PRISM_SOCKS5_IN_PORT="${pt}"
export PRISM_SOCKS5_IN_USER="${u}"
export PRISM_SOCKS5_IN_PASS="${p}"
EOF
               export PRISM_SOCKS5_IN_ENABLE="true"
               export PRISM_SOCKS5_IN_PORT="${pt}"
               source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "安裝成功"; sleep 1; source "${CONFIG_DIR}/secrets.env" ;;
            2) manage_rule_file "socks5_in.list" "Socks5入站" "view" ;;
            3) manage_rule_file "socks5_in.list" "Socks5入站" "add" ;;
            4) if [[ "${PRISM_SOCKS5_IN_ENABLE}" == "true" ]]; then echo -e "\n ${G}Socks5 入站配置:${N}"; echo -e " 地址: ${Y}$(curl -s4m2 https://api.ipify.org)${N}"; echo -e " 端口: ${Y}${PRISM_SOCKS5_IN_PORT}${N}"; echo -e " 用戶: ${Y}${PRISM_SOCKS5_IN_USER}${N}"; echo -e " 密碼: ${Y}${PRISM_SOCKS5_IN_PASS}${N}"; else warn "未安裝 Socks5 入站"; fi; read -p "按回車..." ;;
            5) 
               sed -i '/export PRISM_SOCKS5_IN_/d' "${CONFIG_DIR}/secrets.env"
               export PRISM_SOCKS5_IN_ENABLE="false"
               unset PRISM_SOCKS5_IN_PORT
               source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "已卸載"; sleep 1; break ;;
            0) break ;;
        esac
    done
}

menu_socks5_main() {
    while true; do
        clear; print_banner
        echo -e " ${P}>>> Socks5 分流${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}Socks5 出站${N}      ${D}(連接外部代理)${N}"
        echo -e "  ${P}2.${N} ${W}Socks5 入站${N}      ${D}(作為代理服務器)${N}"
        echo -e "  ${P}3.${N} ${R}卸載全部${N}"
        echo -e "${D}  ------------------------------------${N}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        case "$choice" in
            1) menu_socks5_out_sub ;;
            2) menu_socks5_in_sub ;;
            3) 
                sed -i '/export PRISM_SOCKS5_/d' "${CONFIG_DIR}/secrets.env"
                export PRISM_SOCKS5_OUT_ENABLE="false"
                export PRISM_SOCKS5_IN_ENABLE="false"
                source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "卸載完畢"; sleep 1 ;;
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
        echo -e "  ${P}3.${N} ${R}卸載 DNS 分流${N}"
        echo -e "${D}  ------------------------------------${N}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        case "$choice" in
            1) 
                echo ""; read -p "DNS IP (如 8.8.8.8): " dip; read -p "域名 (逗號分隔): " dlist
                cat >> "${CONFIG_DIR}/secrets.env" <<EOF
export PRISM_DNS_ENABLE="true"
export PRISM_DNS_IP="${dip}"
EOF
                echo "$dlist" | tr ',' '\n' > "${RULE_DIR}/dns.list"
                source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "添加完畢"; sleep 1 ;;
            3) sed -i '/export PRISM_DNS_/d' "${CONFIG_DIR}/secrets.env"; rm "${RULE_DIR}/dns.list"; source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "卸載完畢"; sleep 1 ;;
            0) break ;;
        esac
    done
}

menu_sni_sub() {
    while true; do
        clear; print_banner
        echo -e " ${P}>>> SNI 反向代理分流${N}"
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}添加 SNI 分流${N}"
        echo -e "  ${P}3.${N} ${R}卸載 SNI 分流${N}"
        echo -e "${D}  ------------------------------------${N}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        case "$choice" in
            1) echo ""; read -p "SNI IP: " sip; read -p "域名 (逗號分隔): " slist
               cat >> "${CONFIG_DIR}/secrets.env" <<EOF
export PRISM_SNI_ENABLE="true"
export PRISM_SNI_IP="${sip}"
EOF
               echo "$slist" | tr ',' '\n' > "${RULE_DIR}/sni.list"
               source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "添加完畢"; sleep 1 ;;
            3) sed -i '/export PRISM_SNI_/d' "${CONFIG_DIR}/secrets.env"; rm "${RULE_DIR}/sni.list"; source "${BASE_DIR}/modules/config.sh"; build_config; systemctl restart prism; success "卸載完畢"; sleep 1 ;;
            0) break ;;
        esac
    done
}

submenu_routing() {
    while true; do
        clear; print_banner
        echoContent skyBlue " 分流工具 (Routing Tools) "
        echoContent red " ================================================= "
        
        local warp_status="${D}[未啟用]${N}"
        if [[ "${PRISM_WARP_ENABLE:-}" == "true" ]]; then warp_status="${G}[已啟用]${N}"; fi
        
        echo -e "  ${P}1.${N} ${W}WARP 分流 (第三方 IPv4)${N}  ${warp_status}"
        echo -e "  ${P}2.${N} ${W}WARP 分流 (第三方 IPv6)${N}"
        echo -e "  ${P}3.${N} ${W}IPv6 分流${N}        ${D}(指定域名走 IPv6)${N}"
        echo -e "  ${P}4.${N} ${W}Socks5 分流${N}      ${D}(替換任意門分流)${N}"
        echo -e "  ${P}5.${N} ${W}DNS 分流${N}         ${D}(指定域名用特殊 DNS)${N}"
        echo -e "  ${P}6.${N} ${W}SNI 反向代理分流${N}"
        echo -e "${D}  ------------------------------------${N}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echoContent red " ================================================= "
        echo -ne " 請輸入選項: "; read -r choice
        
        case "$choice" in
            1) menu_warp_sub "IPv4" ;;
            2) menu_warp_sub "IPv6" ;;
            3) menu_ipv6_sub ;;
            4) menu_socks5_main ;;
            5) menu_dns_sub ;;
            6) menu_sni_sub ;;
            0) break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
    show_menu
}