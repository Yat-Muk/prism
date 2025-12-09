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
    OS_RELEASE="Unknown"
    OS_VERSION=""
    PKG_MANAGER=""
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_RELEASE="${ID}"
        OS_VERSION="${VERSION_ID}"
    fi

    case "${OS_RELEASE}" in
        ubuntu|debian|kali|linuxmint|armbian|raspbian)
            PKG_MANAGER="apt"
            PKG_UPDATE_CMD="apt-get update -y"
            PKG_INSTALL_CMD="apt-get install -y --no-install-recommends"
            ;;
        centos|rhel|fedora|almalinux|rocky|amzn|ol)
            PKG_MANAGER="yum"
            PKG_UPDATE_CMD="yum update -y"
            PKG_INSTALL_CMD="yum install -y"
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
                PKG_UPDATE_CMD="dnf update -y"
                PKG_INSTALL_CMD="dnf install -y"
            fi
            ;;
        alpine)
            PKG_MANAGER="apk"
            PKG_UPDATE_CMD="apk update"
            PKG_INSTALL_CMD="apk add --no-cache"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            PKG_UPDATE_CMD="pacman -Sy"
            PKG_INSTALL_CMD="pacman -S --noconfirm --needed"
            ;;
        *)
            if command -v apt-get &>/dev/null; then PKG_MANAGER="apt"; 
            elif command -v yum &>/dev/null; then PKG_MANAGER="yum";
            elif command -v apk &>/dev/null; then PKG_MANAGER="apk"; fi
            ;;
    esac

    if [[ -n "${OS_RELEASE}" ]]; then
        OS_RELEASE="$(tr '[:lower:]' '[:upper:]' <<< ${OS_RELEASE:0:1})${OS_RELEASE:1}"
    fi

    export OS_RELEASE OS_VERSION PKG_MANAGER PKG_UPDATE_CMD PKG_INSTALL_CMD
}

install_base_dependencies() {
    local required_cmds="curl wget tar socat jq openssl gawk"
    local missing_packages=""
    
    if [[ "${PKG_MANAGER}" == "apt" ]]; then
        [[ ! -x "$(command -v lsof)" ]] && missing_packages="${missing_packages} lsof"
        [[ ! -x "$(command -v crontab)" ]] && missing_packages="${missing_packages} cron"
    elif [[ "${PKG_MANAGER}" =~ (yum|dnf) ]]; then
        [[ ! -x "$(command -v lsof)" ]] && missing_packages="${missing_packages} lsof"
        [[ ! -x "$(command -v crontab)" ]] && missing_packages="${missing_packages} crontabs"
        if ! command -v jq &>/dev/null; then
             if ! rpm -q epel-release >/dev/null 2>&1; then
                 echo "正在安裝 EPEL 源 (for jq)..."
                 ${PKG_INSTALL_CMD} epel-release >/dev/null 2>&1
             fi
        fi
    fi

    for cmd in ${required_cmds}; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_packages="${missing_packages} ${cmd}"
        fi
    done

    if [[ -n "${missing_packages}" ]]; then
        info "正在安裝依賴: ${missing_packages}"
        ${PKG_UPDATE_CMD} >/dev/null 2>&1
        if ! ${PKG_INSTALL_CMD} ${missing_packages} >/dev/null 2>&1; then
            error "依賴安裝失敗，請嘗試手動運行: ${PKG_INSTALL_CMD} ${missing_packages}"
            return 1
        fi
    fi
}

create_shortcuts() {
    local target_script="${BASE_DIR}/install.sh"
    info "正在註冊全局命令..."
    chmod +x "${target_script}"
    ln -sf "${target_script}" /usr/bin/prism
    ln -sf "${target_script}" /usr/bin/vasma
    success "快捷指令已註冊: 'prism'"
}

get_kernel_version() { uname -r; }

get_bbr_status() {
    local bbr=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    echo "${bbr:-unknown}"
}
