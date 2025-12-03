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
        *) error "Sing-box 不支持此 CPU 架構: ${machine_arch}"; exit 1 ;;
    esac
}

get_remote_version() {
    local type="$1"
    local version=""
    if [[ "$type" == "prerelease" ]]; then
        version=$(curl -sL --max-time 3 -H "User-Agent: Prism" "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r 'map(select(.prerelease)) | first | .tag_name')
    else
        version=$(curl -sL --max-time 3 -H "User-Agent: Prism" "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r .tag_name)
    fi
    if [[ -z "$version" || "$version" == "null" ]]; then echo "N/A"; else echo "${version}"; fi
}

install_geodata() {
    if [[ -s "${GEO_DIR}/geoip.db" ]] && [[ -s "${GEO_DIR}/geosite.db" ]]; then success "Geo 數據庫已存在"; return; fi
    info "正在部署 Geo 數據庫..."
    local geoip_url="https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db"
    local geosite_url="https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db"
    run_step "下載 GeoIP" "wget -q -O ${GEO_DIR}/geoip.db ${geoip_url}" || true
    run_step "下載 GeoSite" "wget -q -O ${GEO_DIR}/geosite.db ${geosite_url}" || true
}

install_singbox_core() {
    local target_version="$1"
    local install_path="${SINGBOX_BIN}"
    detect_arch
    
    if [[ -z "$target_version" || "$target_version" == "N/A" ]]; then error "無效的版本號。"; return 1; fi
    if [[ "${target_version}" != v* ]]; then target_version="v${target_version}"; fi

    if [[ -f "${install_path}" ]]; then
        local current_version=$("${install_path}" version 2>/dev/null | grep "sing-box version" | awk '{print $3}')
        if [[ "${target_version#v}" == "${current_version#v}" ]]; then
            success "當前已是目標版本 (${target_version})"
            create_systemd_service
            return 0
        fi
    fi

    info "準備安裝 Sing-box: ${target_version} ..."
    local raw_ver="${target_version#v}"
    local filename="sing-box-${raw_ver}-${ARCH_SINGBOX}.tar.gz"
    local download_url="https://github.com/SagerNet/sing-box/releases/download/${target_version}/${filename}"
    local temp_tar="${TEMP_DIR}/singbox.tar.gz"
    
    if ! curl --output /dev/null --silent --head --fail "$download_url"; then error "版本文件不存在"; return 1; fi
    
    rm -f "${temp_tar}"
    run_step "下載核心" "wget -q -O ${temp_tar} ${download_url}"
    
    if [[ ! -f "${temp_tar}" ]]; then error "下載失敗。"; return 1; fi

    local extract_cmd="tar -zxf ${temp_tar} -C ${TEMP_DIR}"
    local install_cmd="mv ${TEMP_DIR}/sing-box-${raw_ver}-${ARCH_SINGBOX}/sing-box ${install_path}"
    local cleanup_cmd="rm ${temp_tar} && rm -rf ${TEMP_DIR}/sing-box-*"
    local chmod_cmd="chmod +x ${install_path}"
    
    run_step "部署二進制文件" "${extract_cmd} && ${install_cmd} && ${chmod_cmd} && ${cleanup_cmd}"
        
    if [[ -f "${install_path}" ]]; then
        success "Sing-box 安裝成功"
        create_systemd_service
        systemctl restart prism
    else
        error "Sing-box 安裝失敗"
        return 1
    fi
}

create_systemd_service() {
    local service_file="/etc/systemd/system/prism.service"
    
    cat > "${service_file}" <<EOF
[Unit]
Description=Prism (Sing-box Core) Service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target
[Service]
User=root
WorkingDirectory=${WORK_DIR}
Environment="ENABLE_DEPRECATED_WIREGUARD_OUTBOUND=true"
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
}

install_kernel() {
    mkdir -p "${WORK_DIR}/bin" "${CONFIG_DIR}"
    install_geodata
    local latest=$(get_remote_version "release")
    install_singbox_core "$latest"
}