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

if [[ -f "${BASE_DIR}/core/network.sh" ]]; then source "${BASE_DIR}/core/network.sh"; fi

write_secret_no_apply() {
    local key="$1"
    local raw_value="$2"
    local file="${CONFIG_DIR}/secrets.env"
    
    if [[ ! -f "${file}" ]]; then touch "${file}"; fi

    local safe_val="${raw_value//\\/\\\\}"
    safe_val="${safe_val//\"/\\\"}"
    safe_val="${safe_val//\$/\\\$}"
    safe_val="${safe_val//\`/\\\`}"

    if grep -q "^export ${key}=" "${file}"; then
        sed -i "s|^export ${key}=.*|export ${key}=\"${safe_val}\"|" "${file}"
    else
        echo "export ${key}=\"${safe_val}\"" >> "${file}"
    fi
    export "${key}=${raw_value}"
}

apply_changes() {
    echo ""
    info "正在應用配置變更..."
    
    if [[ -f "${BASE_DIR}/modules/config.sh" ]]; then
        source "${BASE_DIR}/modules/config.sh"
        
        build_config || { error "配置生成失敗"; return 1; }
        
        systemctl restart prism || warn "服務重啟似乎遇到了問題，請檢查日誌"
        
        if declare -f update_all_port_hopping > /dev/null; then 
            update_all_port_hopping || warn "防火牆規則更新失敗"
        fi
        
        success "更新成功！"
        source "${CONFIG_DIR}/secrets.env"
    fi
}

update_secret() {
    write_secret_no_apply "$1" "$2"
    apply_changes
    read -p " 按回車返回菜單..."
}

change_outbound_mode() {
    local current_mode=$(get_outbound_mode_text)
    clear; print_banner
    echo -e " ${P}>>> 切換出口 IP 優先級${N}"
    echo -e " 當前模式: ${C}${current_mode}${N}"
    echo -e "${SEP}"
    echo -e "  ${P}1.${N} ${G}IPv4 優先${N}   ${D}(默認，最穩定)${N}"
    echo -e "  ${P}2.${N} ${G}IPv6 優先${N}   ${D}(適合特定解鎖)${N}"
    echo -e "  ${P}3.${N} ${Y}僅 IPv4${N}     ${D}(強制走 IPv4)${N}"
    echo -e "  ${P}4.${N} ${Y}僅 IPv6${N}     ${D}(強制走 IPv6)${N}"
    echo -e "${SEP}"
    echo -e "  ${P}0.${N} 返回主菜單"
    echo -e "${SEP}"
    echo -ne " 請輸入選項: "; read -r mode_choice
    
    local new_mode=""
    case "${mode_choice}" in
        1) new_mode="prefer_ipv4" ;; 
        2) new_mode="prefer_ipv6" ;; 
        3) new_mode="ipv4_only" ;; 
        4) new_mode="ipv6_only" ;; 
        0) show_menu; return ;; 
        *) change_outbound_mode; return ;;
    esac
    
    write_secret_no_apply "PRISM_OUTBOUND_MODE" "${new_mode}"
    apply_changes
    sleep 1.5; show_menu
}

select_protocols_wizard() {
    local w_vision=true; local w_grpc=false; local w_hy2=true
    local w_tuic=true; local w_anytls=false; local w_any_reality=false
    local w_shadow=false

    while true; do
        clear; print_banner
        echo -e " ${P}>>> 初次安裝：請選擇要啟用的協議${N}"
        echo -e " ${D}[提示] 輸入數字切換開關，多選用逗號分隔 (如: 2,5,7)${N}"
        echo -e "${SEP}"
        status_icon() { if [[ "$1" == "true" ]]; then echo -e "${G}● 開啟${N}"; else echo -e "${D}○ 關閉${N}"; fi; }
        
        echo -e "  ${P}1.${N} ${W}VLESS Reality Vision${N}  $(status_icon ${w_vision}) ${Y}[推薦]${N}"
        echo -e "  ${P}2.${N} ${W}VLESS Reality gRPC${N}    $(status_icon ${w_grpc})"
        echo -e "  ${P}3.${N} ${W}Hysteria 2 (UDP)${N}      $(status_icon ${w_hy2}) ${Y}[高速]${N}"
        echo -e "  ${P}4.${N} ${W}TUIC v5 (QUIC)${N}        $(status_icon ${w_tuic})"
        echo -e "  ${P}5.${N} ${W}AnyTLS (Standard)${N}     $(status_icon ${w_anytls})"
        echo -e "  ${P}6.${N} ${W}AnyTLS + Reality${N}      $(status_icon ${w_any_reality})"
        echo -e "  ${P}7.${N} ${W}ShadowTLS v3${N}          $(status_icon ${w_shadow})"
        echo -e "${SEP}"
        echo -e "  ${W}Enter.${N} ${B}確認並開始安裝${N}"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r input_str
        
        if [[ -z "$input_str" ]]; then break; fi
        IFS=',' read -ra ADDR <<< "$input_str"
        for choice in "${ADDR[@]}"; do
            case "$choice" in
                1) w_vision=$([[ "$w_vision" == "true" ]] && echo "false" || echo "true") ;;
                2) w_grpc=$([[ "$w_grpc" == "true" ]] && echo "false" || echo "true") ;;
                3) w_hy2=$([[ "$w_hy2" == "true" ]] && echo "false" || echo "true") ;;
                4) w_tuic=$([[ "$w_tuic" == "true" ]] && echo "false" || echo "true") ;;
                5) w_anytls=$([[ "$w_anytls" == "true" ]] && echo "false" || echo "true") ;;
                6) w_any_reality=$([[ "$w_any_reality" == "true" ]] && echo "false" || echo "true") ;;
                7) w_shadow=$([[ "$w_shadow" == "true" ]] && echo "false" || echo "true") ;;
            esac
        done
    done

    write_secret_no_apply "PRISM_ENABLE_REALITY_VISION" "${w_vision}"
    write_secret_no_apply "PRISM_ENABLE_REALITY_GRPC" "${w_grpc}"
    write_secret_no_apply "PRISM_ENABLE_HY2" "${w_hy2}"
    write_secret_no_apply "PRISM_ENABLE_TUIC" "${w_tuic}"
    write_secret_no_apply "PRISM_ENABLE_ANYTLS" "${w_anytls}"
    write_secret_no_apply "PRISM_ENABLE_ANYTLS_REALITY" "${w_any_reality}"
    write_secret_no_apply "PRISM_ENABLE_SHADOWTLS" "${w_shadow}"
    
    success "協議選擇已保存，正在生成密鑰與端口..."
    sleep 1
}

submenu_protocol_switch() {
    while true; do
        clear; print_banner
        echo -e " ${P}>>> 協議管理 (Protocol Switches)${N}"
        echo -e " ${D}[提示] 輸入數字切換開關，多選用逗號分隔 (如: 2,5,7)${N}"
        echo -e "${SEP}"
        status_icon() { if [[ "${1:-false}" == "true" ]]; then echo -e "${G}● 開啟${N}"; else echo -e "${D}○ 關閉${N}"; fi; }
        
        echo -e "  ${P}1.${N} ${W}VLESS Reality Vision${N}  $(status_icon ${PRISM_ENABLE_REALITY_VISION:-false})"
        echo -e "  ${P}2.${N} ${W}VLESS Reality gRPC${N}    $(status_icon ${PRISM_ENABLE_REALITY_GRPC:-false})"
        echo -e "  ${P}3.${N} ${W}Hysteria 2${N}            $(status_icon ${PRISM_ENABLE_HY2:-false})"
        echo -e "  ${P}4.${N} ${W}TUIC v5${N}               $(status_icon ${PRISM_ENABLE_TUIC:-false})"
        echo -e "  ${P}5.${N} ${W}AnyTLS${N}                $(status_icon ${PRISM_ENABLE_ANYTLS:-false})"
        echo -e "  ${P}6.${N} ${W}AnyTLS + Reality${N}      $(status_icon ${PRISM_ENABLE_ANYTLS_REALITY:-false})"
        echo -e "  ${P}7.${N} ${W}ShadowTLS v3${N}          $(status_icon ${PRISM_ENABLE_SHADOWTLS:-false})"
        echo -e "${SEP}"
        echo -e "  ${P}s.${N} ${B}保存並應用${N}"
        echo -e "  ${P}0.${N} 放棄修改"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r input_str
        
        if [[ "$input_str" == "s" ]]; then
             write_secret_no_apply "PRISM_ENABLE_REALITY_VISION" "${PRISM_ENABLE_REALITY_VISION}"
             write_secret_no_apply "PRISM_ENABLE_REALITY_GRPC" "${PRISM_ENABLE_REALITY_GRPC}"
             write_secret_no_apply "PRISM_ENABLE_HY2" "${PRISM_ENABLE_HY2}"
             write_secret_no_apply "PRISM_ENABLE_TUIC" "${PRISM_ENABLE_TUIC}"
             write_secret_no_apply "PRISM_ENABLE_ANYTLS" "${PRISM_ENABLE_ANYTLS}"
             write_secret_no_apply "PRISM_ENABLE_ANYTLS_REALITY" "${PRISM_ENABLE_ANYTLS_REALITY}"
             write_secret_no_apply "PRISM_ENABLE_SHADOWTLS" "${PRISM_ENABLE_SHADOWTLS}"
             apply_changes
             show_menu; return
        elif [[ "$input_str" == "0" ]]; then 
            submenu_config; return
        else
            IFS=',' read -ra ADDR <<< "$input_str"
            for choice in "${ADDR[@]}"; do
                case "$choice" in
                    1) PRISM_ENABLE_REALITY_VISION=$([[ "${PRISM_ENABLE_REALITY_VISION:-false}" == "true" ]] && echo "false" || echo "true") ;;
                    2) PRISM_ENABLE_REALITY_GRPC=$([[ "${PRISM_ENABLE_REALITY_GRPC:-false}" == "true" ]] && echo "false" || echo "true") ;;
                    3) PRISM_ENABLE_HY2=$([[ "${PRISM_ENABLE_HY2:-false}" == "true" ]] && echo "false" || echo "true") ;;
                    4) PRISM_ENABLE_TUIC=$([[ "${PRISM_ENABLE_TUIC:-false}" == "true" ]] && echo "false" || echo "true") ;;
                    5) PRISM_ENABLE_ANYTLS=$([[ "${PRISM_ENABLE_ANYTLS:-false}" == "true" ]] && echo "false" || echo "true") ;;
                    6) PRISM_ENABLE_ANYTLS_REALITY=$([[ "${PRISM_ENABLE_ANYTLS_REALITY:-false}" == "true" ]] && echo "false" || echo "true") ;;
                    7) PRISM_ENABLE_SHADOWTLS=$([[ "${PRISM_ENABLE_SHADOWTLS:-false}" == "true" ]] && echo "false" || echo "true") ;;
                esac
            done
        fi
    done
}

change_reality_sni() {
    clear; print_banner
    echo -e " ${P}>>> 更換 Reality 域名偽裝${N}"
    echo -e " ${D}功能：修改 Reality 協議偷取的目標域名 (需支持 TLSv1.3)${N}"
    echo -e "${SEP}"
    echo -e " 當前 SNI: ${C}${PRISM_DEST:-www.microsoft.com}${N}"
    echo -e "${SEP}"
    echo -e "  ${P}0.${N} 返回"
    echo -e "${SEP}"
    
    read -p " 請輸入新的 SNI (輸入 0 或回車取消): " new_sni
    if [[ "$new_sni" == "0" || -z "$new_sni" ]]; then submenu_config; return; fi
    
    update_secret "PRISM_DEST" "$new_sni"
    show_menu
}

change_uuid() {
    clear; print_banner
    echo -e " ${P}>>> 更換全協議 UUID${N}"
    echo -e " ${D}功能：重置所有協議的用戶 ID${N}"
    echo -e "${SEP}"
    echo -e " 當前 UUID: ${C}${PRISM_UUID}${N}"
    echo -e "${SEP}"
    echo -e "  ${P}1.${N} 自動生成 (推薦)"
    echo -e "  ${P}2.${N} 手動輸入"
    echo -e "${SEP}"
    echo -e "  ${P}0.${N} 返回"
    echo -e "${SEP}"
    echo -ne " 選擇: "; read -r choice
    
    local new_uuid=""
    case "$choice" in 
        1) new_uuid=$(${SINGBOX_BIN} generate uuid) ;; 
        2) read -p " 請輸入新 UUID (輸入 0 取消): " input_uuid
           if [[ "$input_uuid" == "0" ]]; then submenu_config; return; fi
           new_uuid="$input_uuid" 
           ;; 
        0) submenu_config; return ;; 
        *) error "無效"; sleep 1; change_uuid; return ;; 
    esac

    if [[ -n "$new_uuid" ]]; then
        write_secret_no_apply "PRISM_UUID" "$new_uuid"
        write_secret_no_apply "PRISM_TUIC_UUID" "$new_uuid"
        apply_changes
        show_menu; return
    fi
    submenu_config
}

change_port_menu() {
    while true; do
        clear; print_banner
        echo -e " ${B}>>> 更換端口 (Change Port)${N}"
        echo -e "${SEP}"
        
        local options=(); local index=1
        add_opt() {
            local name=$1; local var=$2; local enable=$3; local hopping_var=$4
            if [[ "${!enable:-false}" == "true" ]]; then
                local current_port="${!var:-Unset}"
                local hopping_info=""
                if [[ -n "$hopping_var" ]]; then
                     local hop_val="${!hopping_var:-}"
                     if [[ -n "$hop_val" ]]; then hopping_info=" ${G}[多端口: ${hop_val}]${N}"; fi
                fi
                echo -e "  ${P}${index}.${N} ${W}${name}${N}: ${Y}${current_port}${N}${hopping_info}"
                options[index]="$var|$hopping_var"
                ((index++))
            fi
        }
        
        add_opt "VLESS Reality Vision" "PRISM_PORT_REALITY_VISION" "PRISM_ENABLE_REALITY_VISION" ""
        add_opt "VLESS Reality gRPC"   "PRISM_PORT_REALITY_GRPC"   "PRISM_ENABLE_REALITY_GRPC" ""
        add_opt "Hysteria 2 ${D}(支持端口跳躍)${N}"  "PRISM_PORT_HY2"  "PRISM_ENABLE_HY2" "PRISM_HY2_PORT_HOPPING"
        add_opt "TUIC v5 ${D}(支持多端口復用)${N}"   "PRISM_PORT_TUIC" "PRISM_ENABLE_TUIC" "PRISM_TUIC_PORT_HOPPING"
        add_opt "AnyTLS"               "PRISM_PORT_ANYTLS"         "PRISM_ENABLE_ANYTLS" ""
        add_opt "AnyTLS+Reality"       "PRISM_PORT_ANYTLS_REALITY" "PRISM_ENABLE_ANYTLS_REALITY" ""
        add_opt "ShadowTLS v3"         "PRISM_PORT_SHADOWTLS"      "PRISM_ENABLE_SHADOWTLS" ""
        add_opt "NaiveProxy"           "PRISM_PORT_NAIVE"          "PRISM_ENABLE_NAIVE" ""

        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入要修改的協議編號: "; read -r p_choice
        
        if [[ "$p_choice" == "0" ]]; then break; fi
        
        local target_info="${options[p_choice]}"
        if [[ -z "$target_info" ]]; then error "無效選擇"; sleep 1; continue; fi

        local target_var=$(echo "$target_info" | cut -d'|' -f1)
        local hopping_var=$(echo "$target_info" | cut -d'|' -f2)
        
        local hop_mode="1"
        if [[ -n "$hopping_var" ]]; then
            echo ""; echo -e " ${B}>>> 請選擇端口模式${N}"
            echo -e "${SEP}"
            echo -e "  1. ${W}單端口模式${N} (清除跳躍規則)"
            echo -e "  2. ${W}多端口跳躍/復用${N} (Port Hopping)"
            echo -e "${SEP}"
            echo -e "  0. 取消"
            echo -e "${SEP}"
            read -p " 請選擇: " hop_mode_select
            if [[ "$hop_mode_select" == "0" ]]; then continue; fi
            if [[ "$hop_mode_select" == "2" ]]; then hop_mode="2"; fi
        fi

        echo ""; echo -e " 當前主端口: ${C}${!target_var:-Unset}${N}"
        local new_port=""
        while true; do
            read -p " 請輸入新端口 (1-65535) [回車保持不變, 0 取消]: " input_port
            if [[ "$input_port" == "0" ]]; then continue 2; fi
            if [[ -z "$input_port" ]]; then new_port="${!target_var}"; break;
            elif [[ "$input_port" =~ ^[0-9]+$ ]] && [ "$input_port" -ge 1 ] && [ "$input_port" -le 65535 ]; then new_port="$input_port"; break;
            else echo -e "${R} 端口無效，請重新輸入。${N}"; fi
        done

        write_secret_no_apply "$target_var" "$new_port"
        
        if [[ -n "$hopping_var" ]]; then
            if [[ "$hop_mode" == "1" ]]; then
                write_secret_no_apply "$hopping_var" ""
            elif [[ "$hop_mode" == "2" ]]; then
                echo ""; echo -e " ${P}配置端口跳躍範圍${N}"; echo -e " ${D}示例: 20000:30000 (建議大於 1000)${N}"
                while true; do
                    read -p " 請輸入範圍 (格式 min:max，輸入 0 取消): " hop_range
                    if [[ "$hop_range" == "0" ]]; then continue 2; fi
                    if [[ "$hop_range" =~ ^[0-9]+:[0-9]+$ ]]; then
                            local s=${hop_range%%:*}
                            local e=${hop_range##*:}
                            if (( s < e && s >= 1 && e <= 65535 )); then write_secret_no_apply "$hopping_var" "$hop_range"; break;
                            else echo -e "${R} 範圍無效${N}"; fi
                    else echo -e "${R} 格式錯誤${N}"; fi
                done
            fi
        fi
        
        apply_changes
    done
    submenu_config
}

action_reset_all() {
    if [[ -f "${BASE_DIR}/modules/config.sh" ]]; then
        source "${BASE_DIR}/modules/config.sh"
        local preserved_config=""; if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then preserved_config=$(grep -E "^export PRISM_ENABLE_|^export PRISM_OUTBOUND_MODE" "${CONFIG_DIR}/secrets.env"); fi
        echo -e "${R}警告：將重置所有 UUID、密鑰和端口！${N}"; read -p "確認重置？[y/N]: " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then submenu_config; return; fi
        warn "正在清除舊數據..."; unset $(compgen -v PRISM_); rm -f "${CONFIG_DIR}/secrets.env"
        if [[ -n "$preserved_config" ]]; then eval "$preserved_config"; fi
        check_network_stack; warn "正在生成全新配置..."; build_config; systemctl restart prism; success "配置已重置"; source "${CONFIG_DIR}/secrets.env"
    fi; sleep 2; submenu_config
}

submenu_config() {
    clear; print_banner
    echo -e " ${P}>>> 配置與協議管理${N}"
    echo -e "${SEP}"
    echo -e "  ${P}1.${N} ${W}協議管理${N}          ${D}(開啟/關閉 特定協議)${N}"
    echo -e "  ${P}2.${N} ${W}更換 Reality 偽裝${N} ${D}(SNI)${N}"
    echo -e "  ${P}3.${N} ${W}更換 全協議 UUID${N}"
    echo -e "  ${P}4.${N} ${W}更換 端口${N}"
    echo -e "  ${P}5.${N} ${R}重置 所有配置${N}     ${D}(重置所有端口/密鑰)${N}"
    echo -e "${SEP}"
    echo -e "  ${P}0.${N} 返回上級菜單"
    echo -e "${SEP}"
    echo -ne " 請輸入選項: "; read -r sub_choice
    case "${sub_choice}" in
        1) submenu_protocol_switch ;;
        2) change_reality_sni ;;
        3) change_uuid ;;
        4) change_port_menu ;;
        5) action_reset_all ;;
        0) show_menu ;;
        *) submenu_config ;;
    esac
}
