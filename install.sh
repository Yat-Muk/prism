#!/usr/bin/env bash

# Copyright (C) 2025 Yat-muk <https://github.com/Yat-Muk/prism>
# License: GNU General Public License v3.0

# =================================================
#   :: Prism Network Stack ::
#   Author: Yat-muk
#   Version: v2.0.0
#   Github: https://github.com/Yat-Muk/prism
# =================================================

set -euo pipefail

CURRENT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$CURRENT_SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$CURRENT_SOURCE" )" >/dev/null 2>&1 && pwd )"
    CURRENT_SOURCE="$(readlink "$CURRENT_SOURCE")"
    [[ $CURRENT_SOURCE != /* ]] && CURRENT_SOURCE="$DIR/$CURRENT_SOURCE"
done
export BASE_DIR="$( cd -P "$( dirname "$CURRENT_SOURCE" )" >/dev/null 2>&1 && pwd )"

source "${BASE_DIR}/core/env.sh"
source "${BASE_DIR}/core/log.sh"
source "${BASE_DIR}/core/ui.sh"
source "${BASE_DIR}/core/sys.sh"
source "${BASE_DIR}/core/network.sh"

if [[ -f "${BASE_DIR}/modules/menu.sh" ]]; then
    source "${BASE_DIR}/modules/menu.sh"
else
    echo "Error: Critical module 'modules/menu.sh' not found."
    exit 1
fi

main() {
    check_root
    
    if [[ ! -f "${LOG_FILE}" ]]; then
        touch "${LOG_FILE}"
    fi
    
    detect_os
    
    check_network_stack
    
    show_menu
}

trap 'echo -e "\n${R}[Exit]${N}"; exit 1' INT
main "$@"