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

if [[ -f "${BASE_DIR}/modules/cert.sh" ]]; then source "${BASE_DIR}/modules/cert.sh"; fi
if [[ -f "${BASE_DIR}/modules/menu_config.sh" ]]; then source "${BASE_DIR}/modules/menu_config.sh"; fi

get_current_ca() {
    local account_conf="$ACME_HOME/account.conf"
    local ca_name="ZeroSSL (默認)"
    
    if [[ -f "$account_conf" ]]; then
        local server_url=$(grep "^DEFAULT_ACME_SERVER" "$account_conf" | cut -d= -f2- | tr -d "'\" ")
        
        if [[ -z "$server_url" ]]; then
             server_url=$(grep "^DEFAULT_CA" "$account_conf" | cut -d= -f2- | tr -d "'\" ")
        fi

        if [[ -n "$server_url" ]]; then
            case "$server_url" in
                *"letsencrypt"*) ca_name="Let's Encrypt" ;;
                *"zerossl"*) ca_name="ZeroSSL" ;;
                *"google"*) ca_name="Google Public CA" ;;
                *"buypass"*) ca_name="Buypass" ;;
                *"ssl.com"*) ca_name="SSL.com" ;;
                *) ca_name="自定義 (${server_url})" ;;
            esac
        fi
    fi
    echo "$ca_name"
}

get_cert_remaining_days() {
    local cert_file="$1"
    if [[ ! -f "$cert_file" ]]; then echo "N/A"; return; fi
    
    local end_date_str=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
    if [[ -z "$end_date_str" ]]; then echo "Error"; return; fi
    
    local end_timestamp=$(date +%s -d "$end_date_str")
    local current_timestamp=$(date +%s)
    local diff_seconds=$((end_timestamp - current_timestamp))
    local days=$((diff_seconds / 86400))
    
    echo "$days"
}

get_cert_end_date() {
    local cert_file="$1"
    if [[ ! -f "$cert_file" ]]; then echo "N/A"; return; fi
    local raw_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
    if [[ -n "$raw_date" ]]; then date -d "$raw_date" "+%Y-%m-%d %H:%M:%S"; else echo "Unknown"; fi
}

list_local_certs() {
    echo -e " ${W}當前證書列表:${N}"
    local count=0
    
    if [[ -d "${ACME_CERT_DIR}" ]]; then
        shopt -s nullglob
        for cert in "${ACME_CERT_DIR}"/*.crt; do
            if [[ -f "$cert" ]]; then
                local domain_name=$(basename "$cert" .crt)
                local days=$(get_cert_remaining_days "$cert")
                
                local days_display=""
                if [[ "$days" == "Error" ]]; then
                    days_display="${R}(解析錯誤)${N}"
                elif [[ "$days" -lt 0 ]]; then
                    days_display="${R}(已過期 ${days#-} 天)${N}"
                elif [[ "$days" -lt 30 ]]; then
                    days_display="${Y}(剩餘 ${days} 天)${N}"
                else
                    days_display="${G}(剩餘 ${days} 天)${N}"
                fi
                
                echo -e "  - ${G}[ACME]${N} ${W}${domain_name}${N} ${days_display}"
                count=$((count + 1))
            fi
        done
        shopt -u nullglob
    fi
    
    if [[ -f "${CERT_DIR}/self_signed.crt" ]]; then
        local days=$(get_cert_remaining_days "${CERT_DIR}/self_signed.crt")
        echo -e "  - ${Y}[Self]${N} ${W}自簽名證書 www.bing.com${N} ${G}(剩餘 ${days} 天)${N}"
        count=$((count + 1))
    fi
    
    if [[ "$count" -eq 0 ]]; then echo -e "  ${D}(暫無證書 / No Certificates Found)${N}"; fi
    echo -e "${SEP}"
}

view_cert_details() {
    clear; print_banner
    echo -e " ${P}>>> 證書詳細列表 (Certificate Details)${N}"
    echo -e "${SEP}"
    
    if [[ ! -f "$ACME_HOME/acme.sh" ]]; then
        echo -e " ${R}[Err] acme.sh 未安裝${N}"
        read -p "按回車返回..."
        return
    fi

    local raw_output=$("$ACME_HOME"/acme.sh --list)
    local content=$(echo "$raw_output" | tail -n +2)
    
    if [[ -z "$content" ]]; then
        echo -e "  ${D}(暫無 ACME 證書記錄)${N}"
    else
        while read -r line; do
            if [[ -z "$line" ]]; then continue; fi
            local domain=$(echo "$line" | awk '{print $1}')
            local cert_path="${ACME_CERT_DIR}/${domain}.crt"
            local expiry_info="${D}文件丟失${N}"
            local end_date_str=""
            
            if [[ -f "$cert_path" ]]; then
                local days=$(get_cert_remaining_days "$cert_path")
                end_date_str=$(get_cert_end_date "$cert_path")
                if [[ "$days" -lt 0 ]]; then expiry_info="${R}已過期 ${days#-} 天${N}";
                elif [[ "$days" -lt 30 ]]; then expiry_info="${Y}剩餘 ${days} 天${N}";
                else expiry_info="${G}剩餘 ${days} 天${N}"; fi
            fi
            
            local ca=$(echo "$line" | awk '{print $4}')
            local created=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' | head -n1 | sed 's/T/ /;s/Z//')

            echo -e "  ${P}域名 (Domain):${N} ${W}${domain}${N}"
            echo -e "  ${C}機構 (Issuer):${N} ${Y}${ca:-Unknown}${N}"
            echo -e "  ${C}創建 (Create):${N} ${D}${created}${N}"
            echo -e "  ${C}過期 (Expire):${N} ${D}${end_date_str}${N}"
            echo -e "  ${C}狀態 (Status):${N} ${expiry_info}"
            echo -e "${D}  ------------------------------------${N}"
        done <<< "$content"
    fi
    echo -e "${SEP}"
    read -p "按回車返回..."
}

switch_acme_ca() {
    clear; print_banner
    echo -e " ${P}>>> 切換證書頒發機構 (Switch CA)${N}"
    echo -e " ${D}默認 CA 為 ZeroSSL，如遇申請失敗(速率限制)可切換。${N}"
    echo -e "${SEP}"
    echo -e "  ${P}1.${N} ${G}Let's Encrypt${N}  ${D}(推薦，穩定)${N}"
    echo -e "  ${P}2.${N} ${W}ZeroSSL${N}        ${D}(默認，偶爾繁忙)${N}"
    echo -e "  ${P}3.${N} ${W}Google Public CA${N}"
    echo -e "  ${P}4.${N} ${W}Buypass${N}        ${D}(180天有效期)${N}"
    echo -e "${SEP}"
    echo -e "  ${P}0.${N} 返回"
    echo -e "${SEP}"
    echo -ne " 請輸入選項: "; read -r ca_choice
    
    local server_name=""
    case "$ca_choice" in
        1) server_name="letsencrypt" ;;
        2) server_name="zerossl" ;;
        3) server_name="google" ;;
        4) server_name="buypass" ;;
        0) return ;;
        *) error "無效輸入"; sleep 1; return ;;
    esac
    
    if [[ -n "$server_name" ]]; then
        info "正在切換默認 CA 為: ${server_name}..."
        if declare -f install_acme_core > /dev/null; then install_acme_core; fi
        "$ACME_HOME"/acme.sh --set-default-ca --server "$server_name"
        local ret=$?
        
        if [[ $ret -eq 0 ]]; then
            success "切換成功！下次申請證書將使用 ${server_name}。"
        else
            error "切換失敗，acme.sh 返回錯誤碼 $ret"
        fi
    fi
    sleep 1
}

submenu_cert_apply() {
    if declare -f install_acme_core > /dev/null; then install_acme_core; else echo -e "${R}[Err] 核心證書模塊丟失${N}"; read -p "..."; return; fi

    while true; do
        local current_ca=$(get_current_ca)
        
        clear; print_banner
        echo -e " ${P}>>> 申請 ACME 證書${N}"
        echo -e " 當前 CA 機構: ${C}${current_ca}${N}"
        echo -e "${SEP}"
        list_local_certs
        echo -e "  ${P}1.${N} ${W}申請證書${N}     ${D}(HTTP/80端口模式 - 需釋放端口)${N}"
        echo -e "  ${P}2.${N} ${W}申請證書${N}     ${D}(DNS API模式 - 支持泛域名)${N}"
        echo -e "  ${P}3.${N} ${W}查看證書信息${N}"
        echo -e "  ${P}4.${N} ${W}切換 CA 機構${N} ${D}(解決申請失敗/速率限制)${N}"
        echo -e "  ${P}5.${N} ${R}強制續期證書${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r c_choice
        case "${c_choice}" in
            1|2)
                echo ""; read -p "請輸入註冊郵箱 (回車跳過，輸入 0 取消): " u_mail
                if [[ "$u_mail" == "0" ]]; then continue; fi
                if [[ -n "$u_mail" ]]; then register_acme_email "$u_mail"; fi
                
                if [[ "$c_choice" == "1" ]]; then
                    while true; do
                        echo ""; read -p "請輸入域名 (需已解析到本機，輸入 0 返回): " domain
                        if [[ "$domain" == "0" ]]; then break; fi
                        if [[ -z "$domain" ]]; then error "域名不能為空"; continue; fi
                        
                        check_domain_ip "$domain"
                        local ret=$?
                        
                        if [[ $ret -eq 2 ]]; then
                            echo -e " ${Y}提示：如果您使用了 CDN (如 Cloudflare)，IP 不一致是正常的。${N}"
                            echo -ne " ${R}是否強制繼續申請? [y/N]: ${N}"; read -r force_opt
                            if [[ "$force_opt" == "y" || "$force_opt" == "Y" ]]; then
                                issue_cert "$domain" "standalone"
                                read -p "按回車繼續..."; break
                            fi
                        elif [[ $ret -eq 0 ]]; then 
                            issue_cert "$domain" "standalone"
                            read -p "按回車繼續..."; break
                        else 
                            echo ""; warn "域名解析驗證失敗"
                            read -p "重試? [Y/n]: " r
                            if [[ "$r" == "n" || "$r" == "N" ]]; then break; fi
                        fi
                    done
                else
                    while true; do
                        echo ""; read -p "請輸入域名 (支持泛域名，輸入 0 返回): " domain
                        if [[ "$domain" == "0" ]]; then break; fi
                        if [[ -z "$domain" ]]; then error "域名不能為空"; continue; fi
                        
                        echo -e "\n請選擇 DNS 提供商: 1.Cloudflare 2.DNSPod 3.Aliyun 0.返回"
                        read -p "選擇: " dns_opt
                        case "$dns_opt" in
                            1) 
                                read -p "CF Global API Key (輸入 0 取消): " k; if [[ "$k" == "0" ]]; then continue; fi
                                export CF_Key="$k"
                                read -p "CF Email: " e; export CF_Email="$e"
                                issue_cert "$domain" "dns" "dns_cf" 
                                ;;
                            2) 
                                read -p "DNSPod ID (輸入 0 取消): " i; if [[ "$i" == "0" ]]; then continue; fi
                                export DP_Id="$i"
                                read -p "DNSPod Key: " k; export DP_Key="$k"
                                issue_cert "$domain" "dns" "dns_dp" 
                                ;;
                            3) 
                                read -p "Aliyun Key (輸入 0 取消): " k; if [[ "$k" == "0" ]]; then continue; fi
                                export Ali_Key="$k"
                                read -p "Aliyun Secret: " s; export Ali_Secret="$s"
                                issue_cert "$domain" "dns" "dns_ali" 
                                ;;
                            0) continue ;; 
                            *) error "無效選擇"; continue ;;
                        esac
                        read -p "按回車繼續..."; break
                    done
                fi
                ;;
            3) view_cert_details ;;
            4) switch_acme_ca ;;
            5) echo ""; info "正在強制續期..."; "$ACME_HOME"/acme.sh --cron --force; success "執行完畢"; read -p "按回車繼續..." ;;
            0) break ;; 
            *) ;;
        esac
    done
}

submenu_protocol_cert_mode() {
    local protocols=(
        "Hysteria 2"        "PRISM_HY2_CERT_MODE"        "PRISM_ENABLE_HY2"
        "TUIC v5"           "PRISM_TUIC_CERT_MODE"       "PRISM_ENABLE_TUIC"
        "NaiveProxy"        "PRISM_NAIVE_CERT_MODE"      "PRISM_ENABLE_NAIVE"
        "VLESS TLS Vision"  "PRISM_TLS_VISION_CERT_MODE" "PRISM_ENABLE_TLS_VISION"
        "VLESS TLS gRPC"    "PRISM_TLS_GRPC_CERT_MODE"   "PRISM_ENABLE_TLS_GRPC"
        "AnyTLS (Std)"      "PRISM_ANYTLS_CERT_MODE"     "PRISM_ENABLE_ANYTLS"
    )

    while true; do
        if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then source "${CONFIG_DIR}/secrets.env"; fi

        if [[ -z "${PRISM_ACME_DOMAIN:-}" ]]; then
            if [[ -d "${ACME_CERT_DIR}" ]]; then
                local auto_domain=$(find "${ACME_CERT_DIR}" -name "*.crt" -print -quit | xargs basename -s .crt)
                if [[ -n "$auto_domain" ]]; then write_secret_no_apply "PRISM_ACME_DOMAIN" "$auto_domain"; fi
            fi
        fi
        
        clear; print_banner
        echo -e " ${P}>>> 切換證書模式 (Switch Cert Mode)${N}"
        echo -e " ${D}[提示] 多選用逗號分隔 (如: 1,3)。切換後自動應用。${N}"
        echo -e "${SEP}"
        
        local display_index=1
        local map_index=() 

        for ((i=0; i<${#protocols[@]}; i+=3)); do
            local name="${protocols[i]}"
            local mode_var="${protocols[i+1]}"
            local enable_var="${protocols[i+2]}"
            
            if [[ "${!enable_var:-false}" == "true" ]]; then
                local current_mode="${!mode_var:-self_signed}"
                local mode_display=""
                
                if [[ "$current_mode" == "acme" ]]; then
                    local domain_text="${PRISM_ACME_DOMAIN:-未配置}"
                    mode_display="${G}ACME 域名證書${N} ${D}(${domain_text})${N}"
                else
                    mode_display="${R}自簽名證書${N} ${D}(www.bing.com)${N}"
                fi

                echo -e "  ${P}${display_index}.${N} ${W}${name}${N}: ${mode_display}"
                map_index[display_index]=$i
                ((display_index++))
            fi
        done
        
        if [[ "$display_index" -eq 1 ]]; then
            echo -e "  ${D}(當前沒有開啟任何需要 TLS 的協議)${N}"
        fi

        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入要切換的協議編號: "; read -r input_str
        
        if [[ "$input_str" == "0" ]]; then break; fi
        if [[ -z "$input_str" ]]; then continue; fi
        
        local changes_made=false
        IFS=',' read -ra ADDR <<< "$input_str"
        for choice in "${ADDR[@]}"; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]]; then warn "無效編號: $choice"; continue; fi
            
            if [[ -n "${map_index[choice]}" ]]; then
                local i=${map_index[choice]}
                local target_var="${protocols[i+1]}"
                local current_mode="${!target_var:-self_signed}"
                local new_mode="acme"
                if [[ "$current_mode" == "acme" ]]; then new_mode="self_signed"; fi
                write_secret_no_apply "$target_var" "$new_mode"
                changes_made=true
            fi
        done

        if [[ "$changes_made" == "true" ]]; then
            if [[ -f "${BASE_DIR}/modules/config.sh" ]]; then 
                source "${BASE_DIR}/modules/config.sh"
                build_config
                systemctl restart sing-box
                success "模式切換並應用成功！"
            fi
            sleep 1.5
        else
            error "無效輸入"
            sleep 1
        fi
    done
}

submenu_cert_main() {
    while true; do
        clear; print_banner
        echo -e " ${P}>>> 證書管理 (Certificate Management)${N}"
        echo -e "${SEP}"
        
        local cert_list=""
        if [[ -d "${ACME_CERT_DIR}" ]]; then
            shopt -s nullglob
            for cert in "${ACME_CERT_DIR}"/*.crt; do
                if [[ -f "$cert" ]]; then
                    local domain_name=$(basename "$cert" .crt)
                    cert_list+="${domain_name} "
                fi
            done
            shopt -u nullglob
        fi
        
        if [[ -n "$cert_list" ]]; then
             echo -e "  當前 ACME 證書: ${G}${cert_list}${N}"
        else
             echo -e "  當前 ACME 證書: ${D}無${N}"
        fi
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}證書管理${N}     ${D}(申請 ACME 證書/證書信息)${N}"
        echo -e "  ${P}2.${N} ${W}切換證書模式${N} ${D}(獨立設置協議證書)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        case "${choice}" in
            1) submenu_cert_apply ;;
            2) submenu_protocol_cert_mode ;;
            0) break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
    show_menu
}
