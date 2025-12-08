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
source "${BASE_DIR}/core/sys.sh"


get_bbr_info() {
    current_kernel=$(uname -r)
    
    if [[ -r /proc/sys/net/ipv4/tcp_congestion_control ]]; then
        current_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
    else
        current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    fi

    if [[ -r /proc/sys/net/core/default_qdisc ]]; then
        current_qdisc=$(cat /proc/sys/net/core/default_qdisc)
    else
        current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    fi
    
    current_bbr_ver="${D}未知/未啟用${N}"
    if [[ "$current_cc" == "bbr" ]]; then
        if command -v modinfo &>/dev/null; then
            local mod_info=$(modinfo tcp_bbr 2>/dev/null)
            if echo "$mod_info" | grep -iq "v2"; then current_bbr_ver="${C}BBRv2${N}";
            elif echo "$mod_info" | grep -iq "v3"; then current_bbr_ver="${G}BBRv3${N}";
            else
                if [[ "$current_kernel" == *"xanmod"* ]]; then current_bbr_ver="${G}BBRv3${N} ${D}(XanMod)${N}";
                else current_bbr_ver="${Y}BBRv1${N} ${D}(Mainline)${N}"; fi
            fi
        else
            current_bbr_ver="${Y}BBRv1${N}"
        fi
    fi
    
    if [[ "$current_cc" == "bbr" && "$current_qdisc" == *"fq"* ]]; then
        bbr_status_icon="${G}● 運行中${N}"
    else
        bbr_status_icon="${R}○ 未啟用${N}"
    fi
}

install_xanmod_kernel() {
    clear; print_banner
    echo -e " ${R}>>> 危險操作：安裝 XanMod 內核 (BBRv3)${N}"
    echo -e "${D}功能說明：更換為高性能的第三方 XanMod 內核。${N}"
    echo -e "${D}優點：原生支持 BBRv3，針對網絡吞吐和延遲有深度優化。${N}"
    echo -e "${D}風險：更換內核屬高危操作，極少數情況下可能導致 VPS 無法啟動。${N}"
    echo -e "${SEP}"

    local virt_type=""
    if command -v systemd-detect-virt &>/dev/null; then
        virt_type=$(systemd-detect-virt)
    fi

    case "${virt_type}" in
        lxc|openvz|docker|podman|container)
            error "檢測到容器虛擬化環境 (${virt_type})，無法更換內核。"
            echo -e " ${Y}提示：容器共享宿主機內核，請在宿主機開啟 BBR。${N}"
            read -p "按回車返回..."
            return
            ;;
    esac
    
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        error "XanMod 內核僅支持 x86_64 架構，當前為 ${arch}。"
        read -p "按回車返回..."
        return
    fi

    echo -e " ${Y}警告：更換內核可能導致系統無法啟動 (變磚)。${N}"
    echo -e " 請確保你已備份數據，並擁有 VNC/控制台 救磚能力。"
    echo -e "${SEP}"
    
    echo -ne " 請輸入 ${R}yes${N} 確認安裝 (輸入其他取消): "
    read -r confirm
    if [[ "$confirm" != "yes" ]]; then
        warn "操作已取消"
        sleep 1; return
    fi

    echo ""
    info "正在註冊 XanMod 源..."
    
    if ! curl -fSsL https://dl.xanmod.org/gpg.key | gpg --dearmor | tee /usr/share/keyrings/xanmod.gpg > /dev/null; then
        error "GPG Key 下載失敗，請檢查網絡。"
        read -p "按回車返回..."
        return
    fi

    echo 'deb [signed-by=/usr/share/keyrings/xanmod.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-kernel.list

    info "正在更新軟件源..."
    apt-get update

    info "正在安裝內核 (這可能需要幾分鐘)..."
    if apt-get install -y linux-xanmod-x64v2; then
        success "內核安裝成功！"
        
        info "正在寫入 BBR 配置..."
        echo "net.core.default_qdisc=fq" > /etc/sysctl.d/99-prism-bbr.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-prism-bbr.conf
        sysctl --system >/dev/null 2>&1
        
        echo -e "${R}!!! 系統需要重啟以加載新內核 !!!${N}"
        echo -ne " 是否立即重啟? [y/N]: "; read -r reboot_opt
        if [[ "$reboot_opt" == "y" || "$reboot_opt" == "Y" ]]; then
            reboot
        fi
    else
        error "內核安裝失敗，請檢查上方報錯。"
        read -p "按回車返回..."
    fi
}

enable_bbr_only() {
    echo ""; echo -e "${D}功能說明：在當前內核上啟用原版 BBR 擁塞控制算法。${N}"
    info "正在開啟原版 BBR..."
    if grep -q "bbr" /etc/sysctl.conf; then
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    fi
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    success "BBR 已啟用"
    sleep 1.5
}

sys_optimize() {
    echo ""; echo -e "${D}功能說明：優化 Linux 網絡棧參數、文件句柄限制，提升高併發性能。${N}"
    info "正在應用系統優化參數..."
    cat > /etc/sysctl.d/99-prism-opt.conf <<EOF
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
EOF
    sysctl --system >/dev/null 2>&1
    success "優化完成 (文件句柄/TCP緩衝區)"
    sleep 1.5
}

bbr_traffic_monitor() {
    if ! command -v ss &> /dev/null; then
        error "缺少 ss 命令 (請安裝 iproute2)"
        return
    fi

    local has_tput=false
    if command -v tput &>/dev/null; then has_tput=true; fi

    if [[ "$has_tput" == "true" ]]; then tput civis; fi
    trap 'if [[ "$has_tput" == "true" ]]; then tput cnorm; fi; return' INT

    while true; do
        clear
        print_banner
        echo -e " ${B}>>> BBR 實時流量監控${N}"
        echo -e " ${D}提示：按 ${Y}Ctrl+C${D} 退出監控${N}"
        echo -e "${SEP}"
        echo -e " 當前內核: ${C}${current_kernel}${N}"
        echo -e " 擁塞控制: ${C}${current_cc:-unknown}${N}"
        echo -e " 隊列算法: ${C}${current_qdisc:-unknown}${N}"
        echo -e " BBR 版本: ${current_bbr_ver}"
        echo -e " 運行狀態: ${bbr_status_icon}"
        echo -e "${SEP}"
        
        ss -tinH state established | awk -v P="${P}" -v W="${W}" -v G="${G}" -v C="${C}" -v N="${N}" '
            
            function fmt(val) {
                if (val ~ /[KMG]bps/) return val
                n = val; gsub(/[^0-9.]/, "", n); n = n + 0
                if (n >= 1000000000) return sprintf("%.2f Gbps", n / 1000000000)
                if (n >= 1000000)    return sprintf("%.2f Mbps", n / 1000000)
                if (n >= 1000)       return sprintf("%.2f Kbps", n / 1000)
                return n " bps"
            }
            
            NR%2==1 { remote = $4 }
            NR%2==0 { 
                if ($0 ~ /bbr:/) {
                    bw="N/A"; rtt="N/A"; pacing="N/A"
                    gsub(/[(),]/, " ")
                    
                    for(i=1; i<=NF; i++) {
                        if($i ~ /^bw:/) { split($i, a, ":"); bw=fmt(a[2]) }
                        if($i ~ /^minrtt:/) { split($i, a, ":"); rtt=a[2] }
                        if($i ~ /^mrtt:/)   { split($i, a, ":"); rtt=a[2] }
                        if($i ~ /^pacing_rate:/) { split($i, a, ":"); pacing=fmt(a[2]) }
                        if($i == "pacing_rate") { pacing=fmt($(i+1)) }
                    }
                    
                    printf " %s->%s %s\n", C, N, remote
                    printf "    ├── 帶寬 (BW): %s%s%s\n", G, bw, N
                    printf "    ├── 延遲 (RTT): %s%s ms%s\n", G, rtt, N
                    printf "    └── 速率 (Pacing): %s%s%s\n\n", G, pacing, N
                    found=1
                }
            }
            
            END { if (found != 1) print "\n (暫無活躍 BBR 連接...)" }'
        
        if read -t 1 -n 1 -s key; then break; fi
    done
    if [[ "$has_tput" == "true" ]]; then tput cnorm; fi
    return
}

action_bbr() {
    while true; do
        get_bbr_info
        
        clear; print_banner
        echo -e " ${B}>>> BBR 加速管理${N}"
        echo -e "${SEP}"
        echo -e " 當前內核: ${C}${current_kernel}${N}"
        echo -e " 擁塞控制: ${C}${current_cc:-unknown}${N}"
        echo -e " 隊列算法: ${C}${current_qdisc:-unknown}${N}"
        echo -e " BBR 版本: ${current_bbr_ver}"
        echo -e " 運行狀態: ${bbr_status_icon}"
        echo -e "${SEP}"
        
        echo -e "  ${P}1.${N} ${W}安裝 XanMod 內核${N} ${D}(獲取 BBRv3)${N}"
        echo -e "  ${P}2.${N} ${W}啟用 原版BBR${N}     ${D}(僅修改參數)${N}"
        echo -e "  ${P}3.${N} ${W}系統參數優化${N}     ${D}(TCP/文件句柄)${N}"
        echo -e "  ${P}4.${N} ${G}BBR 流量監控${N}     ${D}(實時面板)${N}"
        echo -e "${SEP}"
        echo -e "  ${P}0.${N} 返回上級菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        
        case "$choice" in
            1) install_xanmod_kernel ;;
            2) enable_bbr_only ;;
            3) sys_optimize ;;
            4) bbr_traffic_monitor ;;
            0) break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
}
