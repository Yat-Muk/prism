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

export PROJECT_NAME="Prism"
export PROJECT_AUTHOR="Yat-Muk"
export PROJECT_URL="https://github.com/Yat-Muk/prism"

export WORK_DIR="/etc/prism"
export LOG_FILE="${WORK_DIR}/runtime.log"
export CONFIG_DIR="${WORK_DIR}/conf"
export RULE_DIR="${WORK_DIR}/rules"
export TEMP_DIR="/tmp/prism_install"
export CERT_DIR="${WORK_DIR}/cert"
export ACME_CERT_DIR="${WORK_DIR}/cert_acme"
export ACME_HOME="$HOME/.acme.sh"

export SINGBOX_BIN="/usr/local/bin/sing-box"

export WARP_REG_BIN="${WORK_DIR}/bin/warp-reg"
export GEO_DIR="${WORK_DIR}/bin"

export OS_RELEASE=""
export OS_VERSION=""
export PKG_MANAGER="" 
export PKG_UPDATE_CMD=""
export PKG_INSTALL_CMD=""

if [[ -f "${WORK_DIR}/version" ]]; then
    export PROJECT_VERSION=$(head -n 1 "${WORK_DIR}/version")
else
    export PROJECT_VERSION="v2.2.2"
fi

mkdir -p "${WORK_DIR}" "${CONFIG_DIR}" "${TEMP_DIR}" "${GEO_DIR}" "${CERT_DIR}" "${ACME_CERT_DIR}" "${RULE_DIR}"