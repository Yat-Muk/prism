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
source "${BASE_DIR}/core/log.sh"
source "${BASE_DIR}/core/ui.sh"
source "${BASE_DIR}/core/network.sh"

install_acme_core() {
    if [[ ! -f "$ACME_HOME/acme.sh" ]]; then
        info "正在安裝 Acme.sh 核心..."
        if ! command -v socat &> /dev/null; then
            run_step "安裝 socat" "${PKG_INSTALL_CMD} socat"
        fi
        
        local email="prism_$(date +%s)@gmail.com"
        curl https://get.acme.sh | sh -s email="$email" >> "${LOG_FILE}" 2>&1
        
        if [[ -f "$ACME_HOME/acme.sh" ]]; then
            success "Acme.sh 安裝成功"
        else
            error "Acme.sh 安裝失敗"
            return 1
        fi
    else
        "$ACME_HOME"/acme.sh --upgrade --auto-upgrade >> "${LOG_FILE}" 2>&1
    fi
}

register_acme_email() {
    local email="$1"
    if [[ -z "$email" ]]; then return; fi
    
    info "正在註冊 Acme 賬戶郵箱: ${email}"
    "$ACME_HOME"/acme.sh --register-account -m "${email}" >> "${LOG_FILE}" 2>&1
    if [[ $? -eq 0 ]]; then
        success "郵箱註冊成功"
    else
        warn "郵箱註冊失敗，將繼續使用默認賬戶。"
    fi
}

check_domain_ip() {
    local domain=$1
    info "正在檢測域名解析: ${domain}"
    
    local local_v4=$(get_public_ip "-4")
    local local_v6=$(get_public_ip "-6")
    
    local domain_ips=$(getent hosts "$domain" | awk '{print $1}')
    
    if [[ -z "$domain_ips" ]]; then
        error "無法解析域名 $domain，請檢查 DNS 設置。"
        return 1
    fi

    local match_found=false
    local matched_ip=""

    for ip in $domain_ips; do
        if [[ -n "$local_v4" && "$ip" == "$local_v4" ]]; then
            match_found=true; matched_ip="$ip (IPv4)"; break
        fi
        if [[ -n "$local_v6" && "$ip" == "$local_v6" ]]; then
            match_found=true; matched_ip="$ip (IPv6)"; break
        fi
    done

    if [[ "$match_found" == "true" ]]; then
        success "域名解析驗證通過: ${matched_ip}"
        return 0
    else
        warn "IP 不一致警告！"
        echo -e "  本機 IPv4: ${Y}${local_v4:-無}${N}"
        echo -e "  本機 IPv6: ${Y}${local_v6:-無}${N}"
        echo -e "  域名解析 : ${Y}${domain_ips}${N}"
        echo -e "  ${R}注意：如果開啟了 CDN (Cloudflare)，請確保為灰色雲朵 (DNS Only)！${N}"
        return 2
    fi
}

ensure_port_80_free() {
    if ! lsof -i :80 | grep -q LISTEN; then
        return 0
    fi
    
    warn "檢測到 80 端口被佔用，正在嘗試處理..."
    
    local pid=$(lsof -i :80 -t | head -n1)
    local pname=$(lsof -i :80 | grep LISTEN | head -n1 | awk '{print $1}')
    
    echo -e "  佔用進程: ${C}${pname}${N} (PID: ${pid})"
    
    case "${pname}" in
        nginx|apache2|httpd|caddy)
            info "嘗試停止 Web 服務 (${pname})..."
            systemctl stop "${pname}" 2>/dev/null
            sleep 2
            ;;
    esac
    
    if lsof -i :80 | grep -q LISTEN; then
        error "80 端口仍被佔用。為保證系統安全，Prism 不會強制終止未知進程。"
        echo -e "  請手動停止佔用進程: ${C}kill ${pid}${N} 或 ${C}systemctl stop ${pname}${N}"
        return 1
    else
        success "80 端口已釋放"
        return 0
    fi
}

issue_cert() {
    local domain=$1
    local mode=$2
    local dns_type=${3:-}
    
    mkdir -p "${ACME_CERT_DIR}"

    if [[ "$mode" == "standalone" ]]; then
        if ! ensure_port_80_free; then
            return 1
        fi
        
        info "開始申請證書 (Standalone Mode)..."
        local listen_arg=""
        
        local local_v4=$(get_public_ip "-4")
        local local_v6=$(get_public_ip "-6")
        
        if [[ -z "$local_v4" ]] && [[ -n "$local_v6" ]]; then
             listen_arg="--listen-v6"
        fi
        
        "$ACME_HOME"/acme.sh --issue -d "$domain" --standalone -k ec-256 --force $listen_arg
    
    elif [[ "$mode" == "dns" ]]; then
        info "開始申請證書 (DNS API: ${dns_type})..."
        "$ACME_HOME"/acme.sh --issue --dns "$dns_type" -d "$domain" -d "*.$domain" --force
    fi

    if [[ $? -ne 0 ]]; then
        error "證書申請失敗！請檢查上方報錯信息 (通常是域名解析或 API Key 錯誤)。"
        return 1
    fi

    info "正在安裝證書並配置自動續期..."
    "$ACME_HOME"/acme.sh --install-cert -d "$domain" \
        --key-file       "${ACME_CERT_DIR}/${domain}.key"  \
        --fullchain-file "${ACME_CERT_DIR}/${domain}.crt" \
        --reloadcmd      "systemctl restart sing-box" \
        --ecc > /dev/null

    if [[ -s "${ACME_CERT_DIR}/${domain}.key" ]]; then
        success "證書申請成功！"
        echo -e " 存放位置: ${G}${ACME_CERT_DIR}/${domain}.crt${N}"
        
        if [[ -f "${CONFIG_DIR}/secrets.env" ]]; then
            if grep -q "export PRISM_ACME_DOMAIN=" "${CONFIG_DIR}/secrets.env"; then
                sed -i "s|^export PRISM_ACME_DOMAIN=.*|export PRISM_ACME_DOMAIN=\"${domain}\"|" "${CONFIG_DIR}/secrets.env"
            else
                echo "export PRISM_ACME_DOMAIN=\"${domain}\"" >> "${CONFIG_DIR}/secrets.env"
            fi
            export PRISM_ACME_DOMAIN="${domain}"
        fi
        return 0
    else
        error "證書文件安裝失敗 (權限或路徑錯誤)。"
        return 1
    fi
}

list_certs() {
    "$ACME_HOME"/acme.sh --list
}