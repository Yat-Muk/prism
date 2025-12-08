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

ARCH_SINGBOX=""

detect_arch() {
    local machine_arch=$(uname -m)
    case "${machine_arch}" in
        x86_64|amd64) ARCH_SINGBOX="linux-amd64" ;;
        aarch64|arm64) ARCH_SINGBOX="linux-arm64" ;;
        armv7*|armv6*) error "暫不支持 ARM 32位架構"; exit 1 ;;
        *) error "不支持的 CPU 架構: ${machine_arch}"; exit 1 ;;
    esac
}

get_remote_version() {
    local type="$1"
    local version=""
    
    if [[ "$type" != "prerelease" ]]; then
        local latest_url=$(curl -Is -w %{url_effective} -o /dev/null "https://github.com/SagerNet/sing-box/releases/latest")
        version=$(basename "$latest_url")
    fi
    
    if [[ "$version" != v* ]]; then 
        local api_url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
        if [[ "$type" == "prerelease" ]]; then api_url="https://api.github.com/repos/SagerNet/sing-box/releases"; fi
        version=$(curl -sL --max-time 5 "$api_url" | grep -oE '"tag_name": "v[^"]+"' | head -n1 | cut -d'"' -f4)
    fi
    
    if [[ "$version" != v* ]]; then echo "N/A"; else echo "${version}"; fi
}

install_singbox_core() {
    local target_version="$1"
    local install_path="${SINGBOX_BIN}"
    detect_arch
    
    if [[ -z "$target_version" || "$target_version" == "N/A" ]]; then error "版本號無效"; return 1; fi
    if [[ "${target_version}" != v* ]]; then target_version="v${target_version}"; fi

    if [[ -f "${install_path}" ]]; then
        local current_version=$("${install_path}" version 2>/dev/null | grep "sing-box version" | awk '{print $3}')
        if [[ "${target_version#v}" == "${current_version#v}" ]]; then
            create_systemd_service
            success "已是目標版本 (${target_version})"
            return 0
        fi
    fi

    info "準備安裝 Sing-box: ${target_version} ..."
    local raw_ver="${target_version#v}"
    local filename="sing-box-${raw_ver}-${ARCH_SINGBOX}.tar.gz"
    local download_base="https://github.com/SagerNet/sing-box/releases/download/${target_version}"
    local file_url="${download_base}/${filename}"
    local sum_url="${download_base}/sha256sums"
    
    local temp_tar="${TEMP_DIR}/singbox.tar.gz"
    local temp_sum="${TEMP_DIR}/singbox.sha256"
    
    if ! wget -q --timeout=30 --tries=3 -O "${temp_tar}" "${file_url}"; then 
        error "核心下載失敗 (網絡超時或鏈接無效)"
        return 1 
    fi
    
    if wget -q --timeout=15 --tries=2 -O "${temp_sum}" "${sum_url}"; then
        local expected_sum=$(grep "${filename}" "${temp_sum}" | awk '{print $1}')
        if [[ -n "$expected_sum" ]]; then
            local actual_sum=$(sha256sum "${temp_tar}" | awk '{print $1}')
            if [[ "$expected_sum" != "$actual_sum" ]]; then
                error "致命錯誤：文件校驗失敗！(Checksum Mismatch)"
                rm -f "${temp_tar}"
                return 1
            else
                info "文件完整性校驗通過 (SHA256)"
            fi
        fi
    else
        warn "無法下載校驗文件，跳過完整性檢查。"
    fi

    local extract_cmd="tar -zxf ${temp_tar} -C ${TEMP_DIR}"
    
    local install_dir=$(dirname "${install_path}")
    if [[ ! -d "${install_dir}" ]]; then mkdir -p "${install_dir}"; fi
    
    local install_cmd="mv ${TEMP_DIR}/sing-box-${raw_ver}-${ARCH_SINGBOX}/sing-box ${install_path}"
    local chmod_cmd="chmod +x ${install_path}"
    local cleanup_cmd="rm ${temp_tar} ${temp_sum} && rm -rf ${TEMP_DIR}/sing-box-*"
    
    run_step "部署二進制文件" "${extract_cmd} && ${install_cmd} && ${chmod_cmd} && ${cleanup_cmd}"
    
    if [[ -x "${install_path}" ]]; then
        success "Sing-box 安裝成功"
        create_systemd_service
        return 0
    else
        error "安裝失敗: 二進制文件不可執行"
        return 1
    fi
}

create_systemd_service() {
    local service_file="/etc/systemd/system/sing-box.service"
    
    cat > "${service_file}" <<EOF
[Unit]
Description=Sing-box Service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=${WORK_DIR}
Environment="ENABLE_DEPRECATED_LEGACY_DNS_SERVERS=true"
Environment="ENABLE_DEPRECATED_LEGACY_DOMAIN_STRATEGY_OPTIONS=true"
Environment="ENABLE_DEPRECATED_SPECIAL_OUTBOUNDS=true"
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=${SINGBOX_BIN} run -c ${CONFIG_DIR}/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNPROC=infinity
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable sing-box >/dev/null 2>&1
}

install_kernel() {
    mkdir -p "${WORK_DIR}/bin" "${CONFIG_DIR}"
    local latest=$(get_remote_version "release")
    install_singbox_core "$latest"
}