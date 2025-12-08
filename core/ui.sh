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

if [[ -f "${BASE_DIR}/core/log.sh" ]]; then
    source "${BASE_DIR}/core/log.sh"
elif [[ -f "/etc/prism/core/log.sh" ]]; then
    source "/etc/prism/core/log.sh"
fi

R="\033[31m"      # Red (錯誤/停止)
G="\033[32m"      # Green (成功/運行中)
Y="\033[33m"      # Yellow (提示)
B="\033[34m"      # Blue (鏈接/裝飾)
P="\033[35m"      # Purple (品牌/標題)
C="\033[36m"      # Cyan (參數鍵)
W="\033[37m"      # White (高亮文字)
D="\033[90m"      # Dark Gray (分割線/次要信息)
N="\033[0m"       # Reset

SEP="${D}=================================================${N}"

print_banner() {
    clear
    echo -e "${P}"
    cat << "EOF"
  _____      _                 
 |  __ \    (_)                
 | |__) | __ _ ___ _ __ ___  
 |  ___/ '__| / __| '_ ` _ \ 
 | |   | |  | \__ \ | | | | |
 |_|   |_|  |_|___/_| |_| |_|

   :: Prism Network Stack :: 
EOF
    echo -e "${N}"
}

_ensure_log() {
    if [[ -z "${LOG_FILE}" ]]; then LOG_FILE="/tmp/prism_runtime.log"; fi
    local log_dir=$(dirname "${LOG_FILE}")
    if [[ ! -d "${log_dir}" ]]; then
        mkdir -p "${log_dir}"
        chmod 700 "${log_dir}"
    fi
}

info() { _ensure_log; echo -e "${B}[INFO]${N} $1"; log_info "$1"; }
success() { _ensure_log; echo -e "${G}[ OK ]${N} $1"; log_info "$1"; }
warn() { _ensure_log; echo -e "${Y}[WARN]${N} $1"; log_warn "$1"; }
error() { _ensure_log; echo -e "${R}[ERR ]${N} $1"; log_error "$1"; }

run_step() {
    local msg="$1"
    local cmd="$2"
    _ensure_log
    
    echo -ne "${B}[....]${N} ${msg}..."
    
    bash -c "${cmd}" >> "${LOG_FILE}" 2>&1 &
    local pid=$!
    
    local delay=0.1
    local spinstr='|/-\'
    local temp
    
    tput civis 2>/dev/null
    
    trap 'tput cnorm 2>/dev/null; kill $pid 2>/dev/null; echo -e "\n${R}[ABORT]${N} 用戶終止操作"; exit 1' SIGINT SIGTERM

    while kill -0 "$pid" 2>/dev/null; do
        temp=${spinstr#?}
        printf "\r${P}[ %c  ]${N} ${msg}..." "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    
    trap - SIGINT SIGTERM
    
    wait $pid
    local exit_code=$?
    
    tput cnorm 2>/dev/null
    
    printf "\r\033[K"
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${G}[DONE]${N} ${msg}"
        log_info "Step succeeded: $msg"
        return 0
    else
        echo -e "${R}[FAIL]${N} ${msg}"
        log_error "Step failed: $msg (Exit Code: $exit_code)"
        return 1
    fi
}