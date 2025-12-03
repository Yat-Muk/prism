#!/usr/bin/env bash

# Copyright (C) 2025 Yat-muk <https://github.com/Yat-Muk/prism>
# License: GNU General Public License v3.0

# =================================================
#   :: Prism Network Stack ::
#   Author: Yat-muk
#   Version: v2.0.0
#   Github: https://github.com/Yat-Muk/prism
# =================================================

REPO_URL="https://raw.githubusercontent.com/Yat-Muk/prism/main"
INSTALL_DIR="/etc/prism"
BIN_DIR="/usr/bin"

R="\033[31m"; G="\033[32m"; Y="\033[33m"; N="\033[0m"

CORE_FILES=(
    "core/env.sh"
    "core/ui.sh"
    "core/sys.sh"
    "core/network.sh"
    "core/log.sh"
)

MODULE_FILES=(
    "modules/menu.sh"
    "modules/menu_ops.sh"
    "modules/menu_config.sh"
    "modules/menu_info.sh"
    "modules/menu_cert.sh"
    "modules/menu_routing.sh"
    "modules/menu_core.sh"
    "modules/menu_bbr.sh"
    "modules/config.sh"
    "modules/kernel.sh"
    "modules/cert.sh"
)

echo_info() { echo -e "${Y}[INFO]${N} $1"; }
echo_ok() { echo -e "${G}[ OK ]${N} $1"; }
echo_err() { echo -e "${R}[ERR ]${N} $1"; }

check_env() {
    if [[ $EUID -ne 0 ]]; then
        echo_err "請使用 root 權限運行此腳本 (sudo -i)"
        exit 1
    fi
    
    echo_info "檢查基礎依賴..."
    local deps="wget curl tar"
    local install_cmd=""
    
    if command -v apt-get &> /dev/null; then
        install_cmd="apt-get install -y"
    elif command -v yum &> /dev/null; then
        install_cmd="yum install -y"
    elif command -v apk &> /dev/null; then
        install_cmd="apk add"
    fi
    
    for dep in $deps; do
        if ! command -v $dep &> /dev/null; then
            echo_info "安裝缺失依賴: $dep"
            $install_cmd $dep >/dev/null 2>&1
        fi
    done
    
    mkdir -p "${INSTALL_DIR}/core"
    mkdir -p "${INSTALL_DIR}/modules"
    mkdir -p "${INSTALL_DIR}/bin"
}

download_files() {
    echo_info "正在從 GitHub 拉取最新代碼..."
    local ts=$(date +%s)
    
    for file in "${CORE_FILES[@]}"; do
        if ! wget -q -O "${INSTALL_DIR}/${file}" "${REPO_URL}/${file}?t=${ts}"; then
            echo_err "下載失敗: ${file}"
            echo_err "請檢查網絡連通性"
            exit 1
        fi
    done
    
    for file in "${MODULE_FILES[@]}"; do
        if ! wget -q -O "${INSTALL_DIR}/${file}" "${REPO_URL}/${file}"; then
            echo_err "下載失敗: ${file}"
            exit 1
        fi
    done
    
    wget -q -O "${INSTALL_DIR}/install.sh" "${REPO_URL}/install.sh"
    chmod +x "${INSTALL_DIR}/install.sh"
    
    echo_ok "核心組件下載完成"
}

register_shortcut() {
    rm -f "${BIN_DIR}/prism" "${BIN_DIR}/vasma"
    ln -sf "${INSTALL_DIR}/install.sh" "${BIN_DIR}/prism"
    ln -sf "${INSTALL_DIR}/install.sh" "${BIN_DIR}/vasma"
    chmod +x "${BIN_DIR}/prism"
}

start_prism() {
    export BASE_DIR="${INSTALL_DIR}"
    
    if [[ -f "${INSTALL_DIR}/modules/menu.sh" ]]; then
        source "${INSTALL_DIR}/modules/menu.sh"
        show_menu
    else
        echo_err "主程序加載失敗，文件缺失！"
        exit 1
    fi
}

if [[ "$1" == "update" ]]; then
    check_env
    download_files
    register_shortcut
    echo_ok "更新完成，正在啟動..."
    sleep 1
    start_prism
    exit 0
fi

if [[ -f "${INSTALL_DIR}/modules/menu.sh" && -f "${INSTALL_DIR}/core/env.sh" ]]; then
    start_prism
else
    check_env
    download_files
    register_shortcut
    echo_ok "Prism 安裝成功！快捷指令: prism"
    sleep 1
    start_prism
fi
