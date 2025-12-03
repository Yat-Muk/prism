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

if [[ -z "${LOG_FILE}" ]]; then
    LOG_FILE="/etc/prism/runtime.log"
fi

if [[ ! -f "${LOG_FILE}" ]]; then
    touch "${LOG_FILE}"
    chmod 600 "${LOG_FILE}"
fi

_log_write() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

log_info() { _log_write "INFO" "$1"; }
log_warn() { _log_write "WARN" "$1"; }
log_error() { _log_write "ERROR" "$1"; }
log_debug() { _log_write "DEBUG" "$1"; }