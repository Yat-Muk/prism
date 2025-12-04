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

R="\033[31m"      # Red (錯誤/停止)
G="\033[32m"      # Green (成功/運行中)
Y="\033[33m"      # Yellow (提示)
B="\033[34m"      # Blue (鏈接/裝飾)
P="\033[35m"      # Purple (品牌/標題)
C="\033[36m"      # Cyan (參數鍵)
W="\033[37m"      # White (高亮文字)
D="\033[90m"      # Dark Gray (分割線/次要信息)
N="\033[0m"       # Reset

SEP_LINE="${D}──────────────────────────────────────────────${N}"

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
EOF
    echo -e "   :: Prism Network Stack ::${N}"
    echo -e "${SEP_LINE}"
}

print_header() {
    local title="$1"
    print_banner
    echo -e " ${B}>>> ${title}${N}"
    echo -e "${SEP_LINE}"
}

print_kv() {
    local key="$1"
    local val="$2"
    printf " %b%-14s%b : %b\n" "${C}" "${key}" "${N}" "${W}${val}${N}"
}

print_entry() {
    local index="$1"
    local desc="$2"
    local status="$3"
    
    local status_display=""
    if [[ -n "$status" ]]; then
        status_display=" ${status}"
    fi
    
    printf "  %b%s.%b %s%b\n" "${P}" "${index}" "${N}" "${desc}" "${status_display}"
}

info() { echo -e " ${B}[INFO]${N} $1"; log_info "$1"; }
success() { echo -e " ${G}[ OK ]${N} $1"; log_info "$1"; }
warn() { echo -e " ${Y}[WARN]${N} $1"; log_warn "$1"; }
error() { echo -e " ${R}[ERR ]${N} $1"; log_error "$1"; }

prompt_ask() {
    local prompt_text="$1"
    local default_val="$2"
    local __resultvar=$3
    
    local display_default=""
    if [[ -n "$default_val" ]]; then
        display_default=" ${D}(默認: ${default_val})${N}"
    fi
    
    echo -ne " ${C}?${N} ${prompt_text}${display_default}: "
    read -r input_val
    
    if [[ -z "$input_val" ]]; then
        eval $__resultvar="'$default_val'"
    else
        eval $__resultvar="'$input_val'"
    fi
}

run_step() {
    local msg="$1"
    local cmd="$2"
    
    echo -ne " ${B}[....]${N} ${msg}..."
    
    eval "${cmd}" >> "${LOG_FILE}" 2>&1 &
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    
    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r ${P}[ %c  ]${N} ${msg}..." "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    wait $pid
    local exit_code=$?
    tput cnorm
    
    printf "\r\033[K"
    
    if [ $exit_code -eq 0 ]; then
        echo -e " ${G}[DONE]${N} ${msg}"
        log_info "Step succeeded: $msg"
    else
        echo -e " ${R}[FAIL]${N} ${msg}"
        log_error "Step failed: $msg"
        echo -e " ${R}詳細錯誤: ${LOG_FILE}${N}"
        return 1
    fi
}
