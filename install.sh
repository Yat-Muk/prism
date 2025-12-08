#!/usr/bin/env bash

# Copyright (C) 2025 Yat-muk <https://github.com/Yat-Muk/prism>
# License: GNU General Public License v3.0

# =================================================
#   :: Prism Network Stack ::
#   Author: Yat-muk
#   Version: v2.2.0
#   Github: https://github.com/Yat-Muk/prism
# =================================================

REPO_URL="https://raw.githubusercontent.com/Yat-Muk/prism/main"
INSTALL_DIR="/etc/prism"
BIN_DIR="/usr/bin"
DOWNLOAD_CACHE="/tmp/prism_dl_cache_$(date +%s)"

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
    "modules/menu_tool.sh"
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

    echo_info "檢查基礎環境與依賴..."
    
    local deps="wget curl tar jq openssl"
    local install_cmd=""
    local pkg_manager=""
    
    if command -v apt-get &> /dev/null; then
        pkg_manager="apt"
        install_cmd="apt-get install -y"
    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf"
        install_cmd="dnf install -y"
    elif command -v yum &> /dev/null; then
        pkg_manager="yum"
        install_cmd="yum install -y"
    elif command -v apk &> /dev/null; then
        pkg_manager="apk"
        install_cmd="apk add"
    elif command -v pacman &> /dev/null; then
        pkg_manager="pacman"
        install_cmd="pacman -S --noconfirm"
    else
        echo_err "未識別的系統，無法自動安裝依賴。"
        exit 1
    fi
    
    for dep in $deps; do
        if ! command -v $dep &> /dev/null; then
            echo_info "安裝缺失依賴: $dep"
            if [[ "$pkg_manager" == "yum" && "$dep" == "jq" ]]; then
                 if ! rpm -q epel-release >/dev/null 2>&1; then
                     echo_info "安裝 EPEL 源 (for jq)..."
                     $install_cmd epel-release >/dev/null 2>&1
                 fi
            fi
            $install_cmd $dep >/dev/null 2>&1
        fi
    done
    
    if ! command -v jq &> /dev/null; then
        echo_err "致命錯誤: 依賴 'jq' 安裝失敗。"
        echo_err "Prism 的配置引擎依賴 jq，請手動安裝後重試。"
        exit 1
    fi
    
    mkdir -p "${INSTALL_DIR}/core"
    mkdir -p "${INSTALL_DIR}/modules"
    mkdir -p "${INSTALL_DIR}/bin"
    mkdir -p "${INSTALL_DIR}/conf"
    chmod 700 "${INSTALL_DIR}/conf"
}

download_files() {
    echo_info "正在從 GitHub 拉取最新代碼..."
    local ts=$(date +%s)

    mkdir -p "${DOWNLOAD_CACHE}/core"
    mkdir -p "${DOWNLOAD_CACHE}/modules"

    abort_download() {
        echo_err "文件下載失敗: $1"
        echo_err "已取消更新，您的現有環境未受影響。"
        rm -rf "${DOWNLOAD_CACHE}"
        exit 1
    }

    if ! wget -q --timeout=15 --tries=3 -O "${DOWNLOAD_CACHE}/version" "${REPO_URL}/version?t=${ts}"; then
        echo_err "警告: version 下載失敗 (請檢查網絡)"
    fi
    
    for file in "${CORE_FILES[@]}"; do
        if ! wget -q --timeout=15 --tries=3 -O "${DOWNLOAD_CACHE}/${file}" "${REPO_URL}/${file}?t=${ts}"; then
            abort_download "${file}"
        fi
    done
    
    for file in "${MODULE_FILES[@]}"; do
        if ! wget -q --timeout=15 --tries=3 -O "${DOWNLOAD_CACHE}/${file}" "${REPO_URL}/${file}?t=${ts}"; then
            abort_download "${file}"
        fi
    done

    if ! wget -q --timeout=15 --tries=3 -O "${DOWNLOAD_CACHE}/install.sh" "${REPO_URL}/install.sh?t=${ts}"; then
        abort_download "install.sh"
    fi
    
    echo_info "校驗通過，正在應用更新..."

    cp -rf "${DOWNLOAD_CACHE}/core/"* "${INSTALL_DIR}/core/"
    cp -rf "${DOWNLOAD_CACHE}/modules/"* "${INSTALL_DIR}/modules/"
    cp -f "${DOWNLOAD_CACHE}/install.sh" "${INSTALL_DIR}/install.sh"
    if [[ -f "${DOWNLOAD_CACHE}/version" ]]; then
        cp -f "${DOWNLOAD_CACHE}/version" "${INSTALL_DIR}/version"
    fi

    chmod +x "${INSTALL_DIR}/install.sh"
    
    rm -rf "${DOWNLOAD_CACHE}"
    
    echo_ok "核心組件更新完成"
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
    exec bash "${INSTALL_DIR}/install.sh"
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