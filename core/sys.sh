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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Prism 需要 Root 權限才能運行。"
        info "請嘗試: sudo ./install.sh"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_RELEASE=$ID
        OS_VERSION=$VERSION_ID
    else
        error "無法讀取 /etc/os-release，不支持此操作系統。"
        exit 1
    fi
    
    case "${OS_RELEASE}" in
        ubuntu|debian|kali)
            PKG_MANAGER="apt"
            PKG_UPDATE_CMD="apt-get update -y"
            PKG_INSTALL_CMD="apt-get install -y --no-install-recommends"
            ;;
        centos|rhel|fedora|almalinux|rocky)
            PKG_MANAGER="yum"
            PKG_UPDATE_CMD="yum update -y"
            PKG_INSTALL_CMD="yum install -y"
            ;;
        alpine)
            PKG_MANAGER="apk"
            PKG_UPDATE_CMD="apk update"
            PKG_INSTALL_CMD="apk add --no-cache"
            ;;
        *)
            error "不支持的發行版: ${OS_RELEASE}"
            exit 1
            ;;
    esac
}

install_base_dependencies() {
    local required_cmds="curl wget tar socat jq openssl qrencode"
    local missing_packages=""
    
    if [[ "${PKG_MANAGER}" == "apt" ]]; then
        [[ ! -x "$(command -v lsof)" ]] && missing_packages="${missing_packages} lsof"
        [[ ! -x "$(command -v crontab)" ]] && missing_packages="${missing_packages} cron"
    elif [[ "${PKG_MANAGER}" == "yum" ]]; then
        [[ ! -x "$(command -v lsof)" ]] && missing_packages="${missing_packages} lsof"
        [[ ! -x "$(command -v crontab)" ]] && missing_packages="${missing_packages} crontabs"
    fi

    for cmd in ${required_cmds}; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_packages="${missing_packages} ${cmd}"
        fi
    done

    if [[ -n "${missing_packages}" ]]; then
        info "檢測到缺失依賴，正在補全: ${missing_packages}"
        run_step "更新軟件源緩存" "${PKG_UPDATE_CMD}"
        run_step "安裝依賴組件" "${PKG_INSTALL_CMD} ${missing_packages}"
    fi
}

create_shortcuts() {
    local target_script="${BASE_DIR}/install.sh"
    info "正在註冊全局命令..."
    chmod +x "${target_script}"
    ln -sf "${target_script}" /usr/bin/prism
    ln -sf "${target_script}" /usr/bin/vasma
    success "快捷指令已註冊: 'prism' 或 'vasma'"
}

get_kernel_version() {
    uname -r
}

get_bbr_status() {
    local bbr=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    echo "${bbr:-unknown}"
}